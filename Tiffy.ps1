param
(
    [Parameter(Mandatory = $true)]
    [System.String] $SourceDir,
    [Parameter(Mandatory = $true)]
    [System.String] $DestinationFile
)

Add-Type -AssemblyName System.Drawing

<#
.SYNOPSIS
Merges multiple TIFF file (including multipage TIFFs) into a single mulipage TIFF file.

.DESCRIPTION
Merges multiple TIFF file (including multipage TIFFs) into a single mulipage TIFF file.
This function translated from an GNU v3 licensed C# function by Ryadel
https://www.ryadel.com/en/asp-net-c-sharp-merge-tiff-files-into-single-multipage-tif/

.PARAMETER tiffFiles
Array of byte arrays of each TIFF file to merge

#>
function MergeTiff
{
    [OutputType([Byte[]])]
    param(
        [Byte[][]]$tiffFiles
    )

    [System.Byte[]]$tiffMerge = $null
    [System.IO.MemoryStream]$msMerge = [System.IO.MemoryStream]::New()
    [System.Drawing.Imaging.ImageCodecInfo]$ici = $null

    foreach($i in [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders())
    {
        if($i.MimeType -eq "image/tiff")
        {
            $ici = $i
        }
    }

    [System.Drawing.Imaging.Encoder]$enc = [System.Drawing.Imaging.Encoder]::SaveFlag
    [System.Drawing.Imaging.EncoderParameters]$ep = [System.Drawing.Imaging.EncoderParameters]::New(1)
    
    [System.Drawing.Bitmap]$pages = $null
    $frame = 0

    foreach($tiffFile in $tiffFiles)
    {
        [System.IO.MemoryStream]$imageStream = [System.IO.MemoryStream]::New([Byte[]]$tiffFile)
 
        [System.Drawing.Image]$tiffImage = [System.Drawing.Image]::FromStream($imageStream)

        foreach($guid in $tiffImage.FrameDimensionsList)
        {
            #Create the frame dimension
            [System.Drawing.Imaging.FrameDimension]$dimension = New-Object -TypeName System.Drawing.Imaging.FrameDimension -ArgumentList $guid

            #Gets the total number of frames in the .tiff file
            $noOfPages = $tiffImage.GetFrameCount($dimension)

            for($index = 0;$index -lt $noOfPages; $index++)
            {
                [System.Drawing.Imaging.FrameDimension] $currentFrame = New-Object -TypeName System.Drawing.Imaging.FrameDimension -ArgumentList $guid
                $tiffImage.SelectActiveFrame($currentFrame, $index) | Out-Null

                [System.IO.MemoryStream]$tempImg = New-Object -TypeName System.IO.MemoryStream

                $tiffImage.Save($tempImg, [System.Drawing.Imaging.ImageFormat]::Tiff)
                
                    if($frame -eq 0)
                    {
                        #Save the first frame
                        $pages = [System.Drawing.Bitmap][System.Drawing.Image]::FromStream($tempImg)
                        $ep.param[0] = [System.Drawing.Imaging.EncoderParameter]::New($enc,[long][System.Drawing.Imaging.EncoderValue]::MultiFrame)
                        $pages.Save($msMerge, $ici, $ep)
                    }
                    else
                    {
                        #Save the intermediate frames
                        $ep.Param[0] = [System.Drawing.Imaging.EncoderParameter]::New($enc,[long][System.Drawing.Imaging.EncoderValue]::FrameDimensionPage)
                        $pages.SaveAdd([System.Drawing.Bitmap][System.Drawing.Image]::FromStream($tempImg), $ep)
                    }
                
                $frame = $frame + 1
            }
        }
    }
    if($frame -gt 0)
    {
        #Flush and close
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

[System.Byte[]]$targetFileData = MergeTiff($files.ToArray())

[System.IO.File]::WriteAllBytes($DestinationFile, $targetFileData)