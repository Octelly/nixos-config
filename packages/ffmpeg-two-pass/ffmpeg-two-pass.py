import os
import sys
import shlex
import tempfile
from pathlib import Path
from typing import Tuple
from datetime import timedelta

import click
import ffmpeg
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeRemainingColumn
from humanfriendly import parse_size
from ffmpeg_progress_yield import FfmpegProgress

console = Console()


# -------------------- helpers --------------------

def build_ffmpeg_cmd(input_path: str, output_path: str, codec: str,
                     video_bitrate_bps: int, audio_bitrate_bps: int,
                     is_final_pass: bool, passlogfile: str, preset: str) -> list[str]:
    """
    Build the ffmpeg commandline for a pass and return it as a list.

    Notes
    -----
    Pass 1 always omits audio.

    Parameters
    ----------
    input_path : str
        Path to the input media file.
    output_path : str
        Target output path (or `/dev/null` for analysis pass).
    codec : str
        Video codec to request (e.g. 'libx264').
    video_bitrate_bps : int
        Video bitrate in bits/sec.
    audio_bitrate_bps : int
        Audio bitrate in bits/sec. Will omit audio if <= 0.
    is_final_pass : bool
        If True, construct the final (pass 2) command that writes the output;
        if False, construct pass 1 which writes analysis data to `passlogfile`.
    passlogfile : str
        Path prefix for ffmpeg two-pass state files.
    preset : str
        Encoder preset string.

    Returns
    -------
    list[str]
        The ffmpeg command as a list suitable for `subprocess.Popen`.
    """
    # choose encoder names/params mapping
    vcodec = codec
    vbr_k = f"{max(1, int(video_bitrate_bps // 1000))}k"  # ffmpeg requires a unit suffix
    abr_k = f"{max(1, int(audio_bitrate_bps // 1000))}k" if audio_bitrate_bps > 0 else None

    # ffmpeg-python option: `pass` and `passlogfile` must be passed as kw
    if is_final_pass:
        out_target = output_path
        if audio_bitrate_bps <= 0:
            audio_kwargs = {'an': None}
        else:
            audio_kwargs = {'acodec': 'aac', 'audio_bitrate': abr_k}
    else:
        out_target = os.devnull
        audio_kwargs = {'an': None}
        # When writing to /dev/null ffmpeg cannot infer a container format
        # from the filename. Explicitly request the "null" muxer so ffmpeg
        # accepts the output target on Unix systems.
        extra_kwargs = {'format': 'null'}

    # Build via ffmpeg-python' API but compile to raw command to run via subprocess (gives us full control).
    stream = ffmpeg.input(input_path)
    kwargs = {
        'vcodec': vcodec,
        'video_bitrate': vbr_k,
        'preset': preset,
        'pass': 2 if is_final_pass else 1,
        'passlogfile': passlogfile,
        **audio_kwargs,
    }
    # apply any pass-specific extra kwargs (e.g. null muxer for pass 1)
    if 'extra_kwargs' in locals():
        kwargs.update(extra_kwargs)  # type: ignore[union-attr]
    # some encoders (libsvtav1) prefer 'f' container adjustment or custom options — we keep generic.
    # Use mp4 container for broad compatibility; user can choose .mkv output too.
    proc = stream.output(out_target, **kwargs)
    # For the final pass, force ffmpeg to overwrite the output non-interactively
    # so subsequent encode attempts can replace the file.
    if is_final_pass:
        proc = proc.overwrite_output()
    return proc.compile(cmd=['ffmpeg'])


def stream_and_show(ff_cmd: list[str], logpath: Path, total_seconds: float, label: str) -> int:
    """
    Run an ffmpeg subprocess with live progress using ffmpeg-progress-yield and Rich.

    Notes
    -----
    Uses ffmpeg-progress-yield to parse ffmpeg's progress output and display a
    live progress bar with elapsed time in HH:MM:SS format. stderr is written
    to `logpath` for logging.

    Parameters
    ----------
    ff_cmd : list[str]
        The ffmpeg command to run (as returned by `build_ffmpeg_cmd`).
    logpath : Path
        File path where ffmpeg stderr will be written.
    total_seconds : float
        Video duration in seconds; used to scale progress bar.
    label : str
        Short label to display in the progress UI.

    Returns
    -------
    int
        The subprocess return code (0 on success).
    """
    console.log(f"[grey]Running: {' '.join(shlex.quote(x) for x in ff_cmd)}[/grey]")

    with open(logpath, "wb") as log_file, Progress(
            SpinnerColumn(),
            TextColumn("[bold cyan]{task.description}"),
            BarColumn(),
            TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
            TextColumn("[cyan]{task.fields[elapsed_time]}"),
            TimeRemainingColumn(),
            console=console,
            transient=True,
    ) as progress:
        task = progress.add_task(label, total=total_seconds, elapsed_time="00:00:00")

        try:
            with FfmpegProgress(ff_cmd) as ff:
                # ff.run_command_with_progress() yields cumulative percent values
                for pct in ff.run_command_with_progress():

                    # Calculate elapsed seconds from percentage
                    elapsed_sec = max(0.0, min((pct / 100.0) * total_seconds, total_seconds))
                    progress.update(task, completed=elapsed_sec, elapsed_time=str(timedelta(seconds=round(elapsed_sec))))

                # write captured stderr to the provided logpath
                stderr_text = getattr(ff, 'stderr', None)
                if stderr_text:
                    log_file.write(stderr_text.encode('utf-8', errors='replace'))
                    log_file.flush()

                # derive return code if available
                rc = 0
                proc = getattr(ff, 'process', None)
                if proc is not None:
                    rc = getattr(proc, 'returncode', 0) or 0
                else:
                    rc = getattr(ff, 'returncode', 0) if hasattr(ff, 'returncode') else 0

        except Exception as e:
            console.print(f"[red]Error during encoding: {e}[/red]")
            rc = 1

    return int(rc)


def next_available_path(path: str, max_tries: int = 1000) -> str:
    """
    Return a path that does not yet exist by appending an incrementing
    numeric suffix before the file extension when necessary.

    Examples
    --------
    - `video.mp4` exists -> returns `video.1.mp4`, `video.2.mp4`, ...
    - `archive.tar.gz` exists -> returns `archive.tar.1.gz`, etc.

    Parameters
    ----------
    path : str
        Desired output path.
    max_tries : int
        How many numeric suffixes to try before giving up.

    Returns
    -------
    str
        A path string that does not currently exist.

    Raises
    ------
    RuntimeError
        If no available name is found within `max_tries` attempts.
    """
    p = Path(path)
    if not p.exists():
        return str(p)

    parent = p.parent
    # preserve full suffix chain (e.g. .tar.gz)
    suffixes = "".join(p.suffixes)
    base = p.name[: len(p.name) - len(suffixes)] if suffixes else p.name

    for i in range(1, max_tries + 1):
        candidate = parent / f"{base}.{i}{suffixes}"
        if not candidate.exists():
            return str(candidate)

    raise RuntimeError(f"Unable to find available filename for {path} after {max_tries} tries")


# -------------------- core algorithm --------------------

def compute_video_bitrate_bps(target_bytes: int, duration_s: float, audio_bitrate_bps: int) -> int:
    """
    Compute integer video bitrate (bits/sec) that fits the `target_bytes` budget.

    The calculation subtracts the expected audio contribution (audio_bitrate_bps
    × duration_s) from the total bit budget and divides the remainder by
    `duration_s` to produce a per-second video bitrate.

    Parameters
    ----------
    target_bytes : int
        Maximum allowed output size in bytes.
    duration_s : float
        Duration of the media in seconds.
    audio_bitrate_bps : int
        Audio bitrate in bits per second to reserve from the budget.

    Returns
    -------
    int
        Video bitrate in bits per second (integer). Raises `ValueError` if
        audio alone exceeds the budget.
    """

    total_bits = target_bytes * 8
    audio_bits = int(audio_bitrate_bps * duration_s)
    video_bits = total_bits - audio_bits
    if video_bits <= 0:
        raise ValueError("Audio bitrate alone exceeds target size.")

    return int(video_bits // duration_s)


def main(input_path: str, output_path: str, codec: str,
         duration: float, audio_bitrate_bps: int, target_bytes: int, preset: str,
         max_iters: int = 6) -> Tuple[bool, int]:
    """
    Iteratively encode at decreasing bitrates until output fits within target_bytes.

    Parameters
    ----------
    input_path : str
        Path to input video file
    output_path : str
        Path where output file will be written
    codec : str
        ffmpeg video codec (e.g., 'libx264', 'libx265')
    duration : float
        Video duration in seconds (for bitrate calculation)
    audio_bitrate_bps : int
        Audio bitrate in bits/sec (subtracted from total target budget)
    target_bytes : int
        Maximum output size in bytes
    preset : str
        Encoder preset (speed/quality tradeoff, codec-specific)
    max_iters : int, optional
        Maximum retry attempts (default 6)

    Returns
    -------
    success : bool
        True if output fits within target_bytes
    size : int
        Final output size in bytes, or -1 if missing output
    """
    # initial video bitrate
    video_bitrate_bps = compute_video_bitrate_bps(target_bytes, duration, audio_bitrate_bps)
    console.print(f"[green]Initial video bitrate:[/green] {video_bitrate_bps / 1000:.1f} kbps")

    # result variables
    size = -1

    # do not delete automatically so user can inspect logs if necessary
    tmpdir = tempfile.mkdtemp(prefix="two-pass-")

    passlog = os.path.join(tmpdir, "pass")  # ffmpeg's analysis file
    ffmpeg_log1 = Path(tmpdir) / "pass1.log"  # std log

    # run pass 1 once (analysis)
    # WARN: must use the same encoder settings (codec, preset, ...) in all subsequent pass 2 attempts
    console.print("[blue]Running analysis pass (pass 1)...[/blue]")
    command = build_ffmpeg_cmd(input_path, output_path, codec, video_bitrate_bps, audio_bitrate_bps, is_final_pass=False, passlogfile=passlog, preset=preset)
    return_code = stream_and_show(command, ffmpeg_log1, duration, label="pass 1")
    if return_code != 0:
        console.print(f"[red]Pass 1 failed (rc={return_code}). See {ffmpeg_log1}[/red]")
        return False, -1

    # index from 1 to use in natural language output
    for attempt in range(1, max_iters + 1):
        attempt_log = Path(tmpdir) / f"pass2-{attempt}.log"

        console.print(f"[blue]Attempt {attempt}/{max_iters} — video bitrate {int(video_bitrate_bps / 1000)}k[/blue]")

        command = build_ffmpeg_cmd(input_path, output_path, codec, video_bitrate_bps, audio_bitrate_bps, is_final_pass=True, passlogfile=passlog, preset=preset)
        return_code = stream_and_show(command, attempt_log, duration, label="pass 2")

        if return_code != 0 or not os.path.exists(output_path):
            console.print(f"[red]Pass 2 failed (returned {return_code}). See {attempt_log}[/red]")
            return False, -1

        size = os.path.getsize(output_path)
        console.print(f"Final size: {size} bytes (target {target_bytes})")

        # job done, target reached
        if size <= target_bytes:
            return True, size

        # Let's try again...

        # max: don't go below 1000 bps (1 kbps)
        new_video_bitrate_bps = max(1000, int(video_bitrate_bps * 0.965))
        if new_video_bitrate_bps >= video_bitrate_bps:
            console.print("[red]Cannot decrease bitrate any further.[/red]")
            return False, size

        console.print(f"[yellow]Overshot by {(size - target_bytes)} bytes; reducing bitrate to {new_video_bitrate_bps / 1000:.1f}k and retrying[/yellow]")
        video_bitrate_bps = new_video_bitrate_bps

    console.print("[red]Reached max iterations without meeting target.[/red]")
    return False, size


# -------------------- CLI --------------------

@click.command(context_settings=dict(help_option_names=['-h', '--help']))
@click.option("-i", "--input", "input_path", required=True, type=click.Path(exists=True), help="Input file")
@click.option("-o", "--output", "output_path", required=True, type=click.Path(), help="Output file (container decides support)")
@click.option("-s", "--size", "size_str", required=True, help="Max size (human, e.g. 200M, 50MB, 30000000)")
@click.option("--audio-bitrate", "-a", default=None, help="Force audio bitrate (e.g. 128k or 128000). If omitted, uses source audio bitrate or 128k fallback.")
@click.option("--omit-audio", "-A", 'audio_bitrate', flag_value=0, help="Omits audio (same as setting audio bitrate to 0).")
@click.option("--video-codec", "-c", default="auto", type=click.Choice(["auto", "libx264", "libx265", "libvpx-vp9", "libsvtav1"]), help="Video encoder to use")
@click.option("--preset", "-p", default="medium", help="Encoder preset (encoder-dependent)")
@click.option("--max-iters", default=6, help="Max re-encode iterations (default 6)")
def cli(input_path, output_path, size_str, audio_bitrate, video_codec, preset, max_iters):
    """Encode INPUT -> OUTPUT with strict maximum size SIZE (e.g. 50M)."""

    # parse size
    try:
        target_bytes = int(parse_size(size_str))
    except Exception:
        console.print("[red]Invalid size. Use 50M, 200MB, 30000000 etc.[/red]")
        sys.exit(2)

    # probe input
    try:
        probe_output = ffmpeg.probe(input_path)
    except ffmpeg.Error as e:
        raise RuntimeError(f"ffprobe failed: {e.stderr.decode() if hasattr(e, 'stderr') else e}")

    duration = float(probe_output["format"]["duration"])

    input_audio_bitrate = 0
    for s in probe_output.get("streams", []):
        if s.get("codec_type") == "audio":
            br = s.get("bit_rate")
            if br:
                input_audio_bitrate = int(br)
                break

    # correct probe information
    if audio_bitrate:
        # parse strings like 128k or absolute
        ab = str(audio_bitrate).lower()
        if ab.endswith("k"):
            audio_bitrate_bps = int(float(ab[:-1]) * 1000)
        else:
            audio_bitrate_bps = int(float(ab))
    else:
        audio_bitrate_bps = input_audio_bitrate or 128_000

    # codec selection
    if video_codec == "auto":
        # pick libx264 for speed / compatibility; warn about alternatives
        chosen_codec = "libx264"
    else:
        chosen_codec = video_codec

    # If the requested output file exists, pick a next-available name
    original_output = output_path
    output_path = next_available_path(output_path)
    if str(output_path) != str(original_output):
        console.print(f"[yellow]Note: '{original_output}' exists — writing to '{output_path}' instead.[/yellow]")

    console.print(f"[bold]Input:[/bold] {input_path}")
    console.print(f"[bold]Duration:[/bold] {duration:.1f}s")
    console.print(f"[bold]Audio bitrate (bps):[/bold] {audio_bitrate_bps}")
    console.print(f"[bold]Codec:[/bold] {chosen_codec}  (preset {preset})")
    console.print(f"[bold]Target bytes:[/bold] {target_bytes}")

    ok, final = main(input_path, output_path, chosen_codec, duration, audio_bitrate_bps, target_bytes, preset, max_iters)

    if ok:
        console.print(f"[bold green]Success: final size {final} bytes <= {target_bytes} bytes[/bold green]")
        sys.exit(0)
    else:
        console.print(f"[red]Failed to produce file <= target. Final was {final} bytes[/red]")
        sys.exit(1)


if __name__ == "__main__":
    cli()
