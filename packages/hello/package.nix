{ writeText, system, ... }:
writeText "hello" "hi from ${system}"
