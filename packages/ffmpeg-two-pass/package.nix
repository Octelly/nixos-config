{ writers
, python3Packages
, ...
}:
writers.writePython3Bin "ffmpeg-two-pass"
{
  libraries = with python3Packages; [
    click
    ffmpeg-python
    humanfriendly
    rich
    ffmpeg-progress-yield
  ];
  flakeIgnore = [ "E501" ];
} ./ffmpeg-two-pass.py
