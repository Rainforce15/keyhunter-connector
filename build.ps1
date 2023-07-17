If(!(test-path -PathType container dist))
{
      New-Item -ItemType Directory -Path dist
}
Get-ChildItem -Path src\*, lib\* | Compress-Archive -Force -DestinationPath dist\keyhunter-connector.zip