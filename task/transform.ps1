[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [string] [Parameter(Mandatory = $false)]
    $workingFolder,
    [string] [Parameter(Mandatory = $true)]
    $transforms
)

Trace-VstsEnteringInvocation $MyInvocation
try
{
    # get inputs
    #[string] $workingFolder = Get-VstsInput -Name 'workingFolder'
    #[string] $transforms = Get-VstsInput -Name 'transforms' -Require

    if (!$workingFolder)
    {
        $workingFolder = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
    }

    $workingFolder = $workingFolder.Trim()

    # import assemblies
    Add-Type -Path "${PSScriptRoot}\Microsoft.Web.XmlTransform.dll"

    # apply transforms
    $transforms -split "(?:`n`r?)|," | % {
        $rule = $_.Trim()
        if (!$rule)
        {
            Write-Warning "Found empty rule."
            return
        }

        $ruleParts = $rule -split " *=> *"
        if ($ruleParts.Length -lt 2)
        {
            Write-Error "Invalid rule '${rule}'."
            return
        }

        $xdtRule = $ruleParts[0].Trim()
        $xmlRule = $ruleParts[1].Trim()
        $xdtFile = $xdtRule
        $xmlFile = $xmlRule

        if (![System.IO.Path]::IsPathRooted($xdtFile))
        {
            $xdtFile = Join-Path $workingFolder $xdtFile
        }

        if (![System.IO.Path]::IsPathRooted($xmlFile))
        {
            $xmlFile = Join-Path $workingFolder $xmlFile
        }

        # check for pattern 
        if ($xdtFile.Contains("*") -or $xdtFile.Contains("?")) 
        {
            Write-Verbose "Pattern found in solution parameter."
            Write-Verbose "Find-VstsFiles -LegacyPattern $xdtFile"
            $xdtFiles = Find-VstsFiles -LegacyPattern $xdtFile
            Write-Verbose "transformFiles = $xdtFiles"
        } 
        else 
        { 
            Write-Verbose "No Pattern found in solution parameter."
            $xdtFiles = ,$xdtFile
        } 

        if ($xmlFile.Contains("*") -or $xmlFile.Contains("?")) 
        {
            Write-Verbose "Pattern found in solution parameter."
            Write-Verbose "Find-VstsFiles -LegacyPattern $xmlFile"
            $xmlFiles = Find-VstsFiles -LegacyPattern $xmlFile 
            Write-Verbose "sourceFiles = $xmlFiles"
        } 
        else 
        { 
            Write-Verbose "No Pattern found in solution parameter."
            $xmlFiles = ,$xmlFile
        }

        $xdtFiles | foreach {
            $xdt = $_
            $xml = ($_ -replace ((Split-Path $xdtRule -Leaf) -replace "\*")) + (((Split-Path $xmlRule -Leaf) -replace "\*"))
            Write-Verbose "XDT File = $xdt"
            Write-Verbose "XML File = $xml"       

            $out = $xml
            if ($ruleParts.Length -eq 3)
            {
                $out = $ruleParts[2].Trim()
                if (![System.IO.Path]::IsPathRooted($out))
                {
                    $out = Join-Path $workingFolder $out
                }
            }

            XmlDocTransform($xml,$xdt,$out)
        }
    }
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}

########################################
# Private functions.
########################################
function XmlDocTransform($xml, $xdt, $out) {
[CmdletBinding()]

      if (!($xmlpath) -or !(Test-Path -path ($xmlpath) -PathType Leaf)) {
         throw "Base file not found. $xmlpath";
      }

      if (!($xdtpath) -or !(Test-Path -path ($xdtpath) -PathType Leaf)) {
         throw "Transform file not found. $xdtpath";
      }

      Add-Type -LiteralPath "$PSScriptRoot\Microsoft.Web.XmlTransform.dll"

      $xmldoc = New-Object   Microsoft.Web.XmlTransform.XmlTransformableDocument;
      $xmldoc.PreserveWhitespace = $true
      $xmldoc.Load($xmlpath);

      $transf = New-Object Microsoft.Web.XmlTransform.XmlTransformation($xdtpath);
      if ($transf.Apply($xmldoc) -eq $false)
      {
          throw "Transformation failed."
      }
    
      # save output
      $outputParent = Split-Path $out -Parent
      if (!(Test-Path $outputParent))
      {
          Write-Verbose "Creating folder '${outputParent}'."
      
          New-Item -Path $outputParent -ItemType Directory -Force > $null
      }
      
      $xmldoc.Save($out)

      Write-Host "Transformation succeeded" -ForegroundColor Green
  }