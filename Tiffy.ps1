param
(
    [Parameter(Mandatory = $true)]
    [System.String] $SourceDir,
    [Parameter(Mandatory = $true)]
    [System.String] $DestinationFile
)

Add-Type -AssemblyName System.Drawing

function MergeTiff
{
    param(
        [Byte[][]]$tiffFiles
    )
    [System.Byte[]]$tiffMerge

    [System.IO.MemoryStream]$msMerge = New-Object -TypeName System.IO.MemoryStream

    [System.Drawing.Imaging.ImageCodecInfo]$ici

    foreach($i in [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders())
    {
        if($i.MimeType -eq "image/tiff")
        {
            $ici = $i
        }
    }

    [System.Drawing.Imaging.Encoder]$enc = [System.Drawing.Imaging.Encoder]::SaveFlag
    [System.Drawing.Imaging.EncoderParameters]$ep = [System.Drawing.Imaging.EncoderParameters]::New(1)
    
    [System.Drawing.Bitmap]$pages
    $frame = 0

    foreach($tiffFile in $tiffFiles)
    {
        [System.IO.MemoryStream]$imageStream = [System.IO.MemoryStream]::New([Byte[]]$tiffFile)
 
        [System.Drawing.Image]$tiffImage = [System.Drawing.Image]::FromStream($imageStream)

        foreach($guid in $tiffImage.FrameDimensionsList)
        {
            [System.Drawing.Imaging.FrameDimension]$dimension = New-Object -TypeName System.Drawing.Imaging.FrameDimension -ArgumentList $guid

            $noOfPages = $tiffImage.GetFrameCount($dimension)

            for($index = 0;$index -lt $noOfPages; $index++)
            {
                [System.Drawing.Imaging.FrameDimension] $currentFrame = New-Object -TypeName System.Drawing.Imaging.FrameDimension -ArgumentList $guid
                $tiffImage.SelectActiveFrame($currentFrame, $index) 

                [System.IO.MemoryStream]$tempImg = New-Object -TypeName System.IO.MemoryStream

                $tiffImage.Save($tempImg, [System.Drawing.Imaging.ImageFormat]::Tiff)
                {
                    if($frame -eq 0)
                    {
                        $pages = [System.Imaging.Bitmap][System.Drawing.Image]::FromStream($tempImg)
                        $ep.param[0] = [System.Drawing.Imaging.EncoderParameter]::New($enc,[long][System.Drawing.Imaging.EncoderValue]::MultiFrame)
                        $pages.Save($msMerge, $ici, $ep)
                    }
                    else
                    {
                        $ep.Param[0] = [System.Drawing.Imaging.EncoderParameter]::New($enc,[long][System.Drawing.Imaging.EncoderValue]::FrameDimensionPage)
                        $pages.SaveAdd([System.Imaging.Bitmap][System.Drawing.Image]::FromStream($tempImg), $ep)
                    }
                }
                $frame++
            }
        }
    }
    if($frame -gt 0)
    {
        $ep.Param[0] = [System.Drawing.Imaging.EncoderParameter]::New($enc, [long][System.Drawing.Imaging.EncoderValue]::Flush)
        $pages.SaveAdd($ep)
    }

    $msMerge.Position = 0
    $tiffMerge = $msMerge.ToArray()

    return $tiffMerge 
}

if(-not (Test-Path -Path $SourceDir))
{
    Write-Host "Source Path not found"
    return
}

[System.Collections.Generic.List[System.Byte[]]]$files = @()
foreach($file in Get-ChildItem -Path $SourceDir -Include '*.TIF' )
{
    $files.Add([System.IO.File]::ReadAllBytes($file))
}

$targetFileData = MergeTiff($files.ToArray())

[System.IO.File]::WriteAllBytes($DestinationFile, $targetFileData)