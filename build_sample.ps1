param(
[switch]$test,
[switch]$publish,
[switch]$signature,
[switch]$notAddBuildVer,
[switch]$addMainVer,
[switch]$addSubVer,
[switch]$addPatchVer,
[switch]$packThirdParty,
[string]$branch,
[switch]$notPull,
[switch]$packOnly,
[switch]$notClean,
[switch]$uploadFtp,
[string]$projDir="F:\mediaclient\fx_banzou",
[string]$setVersion,
[switch]$notBuildThirdParty
)

$filename = "F:\fxbz_build.txt"
"build start" | Set-Content $filename 

Write-Host "build start"
$scriptDir=$MyInvocation.MyCommand.Definition|Split-Path -Parent

# load base functions
. $scriptDir\functions.ps1

# init env
$installDir="$projDir\install"
$srcDir="$projDir\src"
$debugDir="$srcDir\Debug"
$releaseDir="$srcDir\Release"
$mainProjName="FanXingPartner"
$mainProjDir="$srcDir\FanXingPartner"
if($env:PROCESSOR_ARCHITECTURE -eq "x86")
{
	$vsInstallDir=(Get-Item HKLM:\SOFTWARE\Microsoft\VisualStudio\12.0).GetValue("InstallDir")
    $nsisDir=(Get-Item HKLM:\SOFTWARE\NSIS).GetValue("")
}
else
{
	$vsInstallDir=(Get-Item HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\12.0).GetValue("InstallDir")
    $nsisDir=(Get-Item HKLM:\SOFTWARE\Wow6432Node\NSIS).GetValue("")
}
$devenv="$vsInstallDir"+"devenv.com"
$makensis="$nsisDir\makensis.exe"
Set-Alias zip $scriptDir\zip.exe
Set-Alias unzip $scriptDir\unzip.exe

if($publish)
{
    $signature=$true
    $addPatchVer=$true
}

# go to project directory
cd $projDir

"git check start...." | Add-Content $filename 
# check branch status
$branchList=git branch
foreach ($_ in $branchList)
{
    if($_ -match "\* (?<branchName>.*)")
    {
        $curBranch=$matches.branchName
        break
    }
}
if((git status -uno --porcelain) -ne $NULL)
{
    # current branch has something to due with first
    Write-Host "current branch:$curBranch has something to due with first"
    "current branch:$curBranch has something to due with first" | Set-Content $filename
    return
}

# update branch list
git fetch

if($branch -and ($branch -ne $curBranch))
{
    # checkout a new local $branch if not exist when there is a remote $branch
    if($branchList -notcontains "  $branch")
    {
        $remoteBranchList=git branch -r
        if($remoteBranchList -contains "  origin/$branch")
        {
            git branch --no-track $branch refs/remotes/origin/$branch
            git branch --set-upstream-to=origin/$branch $branch
        }
    }

    git checkout $branch
    if((git status -uno --porcelain) -ne $NULL)
    {
        # current branch has something to due with first
        Write-Host "branch:$branch has something to due with first"
        "checkout failed,branch:$branch has something to due with first" | Set-Content $filename
        return
    }

    $branchList=git branch
    foreach ($_ in $branchList)
    {
      if($_ -match "\* (?<branchName>.*)")
      {
        $newBranch=$matches.branchName
        break
      }
    }
    if($newBranch -eq $branch)
    {
      $curBranch=$branch
    }
    else
    {
      Write-Host "checkout branch:$branch failed"
      "checkout branch:$branch failed" | Set-Content $filename
      return
    }
}
if(!$notPull -and ((git branch --list -r origin/$curBranch) -ne $NULL))
{
    git pull
}

# absolutely clean code
if(!$notClean)
{
	git clean -fxdq
}

"git check finish..." | Add-Content $filename 

# add build number and update version
$oldVer=(getProjVer $mainProjDir $mainProjName).Split('.')
$mainVer=$oldVer[0] -as [int]
$subVer=$oldVer[1] -as [int]
$patchVer=$oldVer[2] -as [int]
$buildVer=$oldVer[3] -as [int]
if($setVersion)
{
	$v=($setVersion.Split('.'))
	$mainVer=$v[0] -as [int]
	$subVer=$v[1] -as [int]
	$patchVer=$v[2] -as [int]
	$buildVer=$v[3] -as [int]
}
else
{
	if(!$notAddBuildVer)
	{
		$buildVer++
	}
	if($addPatchVer)
	{
		$patchVer++
	}
	if($addSubVer)
	{
		$subVer++
		$patchVer=0
	}
	if($addMainVer)
	{
		$mainVer++
		$patchVer=0
		$subVer=0
	}
}
setProjVer $mainProjDir $mainProjName $mainVer $subVer $patchVer $buildVer

if(!$packOnly)
{
  # unzip and build third-party
  if (!$notBuildThirdParty)
  {
    "unzip third_party.zip ..." | Add-Content $filename 
	Write-Host "unzip third_party"
	unzip -o "$srcDir\third_party.zip" -d "$srcDir"

	"build third_party start..." | Add-Content $filename 
	Write-Host "build sln third_party"
	& $devenv "$srcDir\third_party.sln" /rebuild "release"

	if (!$?)
	{
	    "build third_party failed..." | Add-Content $filename 
		Write-Host "build third_party fail"
		return
	}
	"build third_party finish..." | Add-Content $filename 
  }

  # build
  "building FxbzUpdate start..." | Add-Content $filename 
  & $devenv "$srcDir\FxbzUpdate\FxbzUpdate.sln" /rebuild "release"
  if(!$?)
  {
    Write-Host "build FxbzUpdate fail"
    "build FxbzUpdate failed..." | Add-Content $filename 
    return
  }
  "building FxbzUpdate finish..." | Add-Content $filename 

  "building BoBo start..." | Add-Content $filename 
  & $devenv "$srcDir\BoBo.sln" /rebuild "release"
  if(!$?)
  {
    Write-Host "build BoBo fail"
    "build FanXingBanZou failed..." | Add-Content $filename
    return
  }
  "building BoBo finish..." | Add-Content $filename 
}

# make package
mkdir "$installDir\src_files"
mkdir "$installDir\src_files\effect"
# copy clean debug to release
#copy "$debugDir\*" "$releaseDir" -r -force -Exclude "KGDBQuery.dll"

# copy files to src_files
copy "$releaseDir\*.exe" "$installDir\src_files"
copy "$releaseDir\*.dll" "$installDir\src_files"
del "$installDir\src_files\codecs.dll"
del "$installDir\src_files\kgplayer.dll"
del "$installDir\src_files\libpthread-2.dll"
del "$installDir\src_files\libx264-128.dll"
del "$installDir\src_files\sqlite3.dll"

# "copy resource files from debug"
copy -r "$releaseDir\begin.png" "$installDir\src_files"
copy -r "$releaseDir\effect\beautify" "$installDir\src_files\effect"
copy -r "$releaseDir\init" "$installDir\src_files"
copy -r "$releaseDir\soundeffect" "$installDir\src_files"

# make skin zip and copy to src_files
cd "$debugDir\skin"
mkdir "$installDir\src_files\skin"
zip -r "$installDir\src_files\skin\skin.zip" .
"[info]" | out-file -FilePath "$installDir\src_files\skin\config.ini"
"md5={0}" -f (getMd5 "$installDir\src_files\skin\skin.zip") | out-file -FilePath "$installDir\src_files\skin\config.ini" -Append
cd $projDir

# signature
if($signature)
{
    # to do
    sign "$installDir\src_files"
}

# copy nsis plugins to plugin dir
copy "$installDir\nsis_plugin\*.dll" "$nsisDir\Plugins"
copy "$installDir\nsis_skin\*.dll" "$nsisDir\Plugins"

addPath $nsisDir
if($publish)
{
  $fullPktName="FxBanZouSetup$mainVer.$subVer.$patchVer.$buildVer.full.exe"
  $miniPktName="FxBanZouSetup$mainVer.$subVer.$patchVer.$buildVer.exe"
  $autoPktName="FxBanZouSetup$mainVer.$subVer.$patchVer.$buildVer.autoupdate.exe"
}
else
{
  $fullPktName="FxBanZouSetup$mainVer.$subVer.$patchVer.$buildVer.$curBranch.full.exe"
  $miniPktName="FxBanZouSetup$mainVer.$subVer.$patchVer.$buildVer.$curBranch.exe"
  $autoPktName="FxBanZouSetup$mainVer.$subVer.$patchVer.$buildVer.$curBranch.autoupdate.exe"
}
"makensis min start..." | Add-Content $filename 
makensis "/XOutFile $miniPktName" /DPRODUCT_VERSION_MAIN=$mainVer /DPRODUCT_VERSION_SUB=$subVer /DPRODUCT_VERSION_PATCH=$patchVer /DPRODUCT_VERSION_BUILDNO=$buildVer "$installDir\BoBo.nsi"
if(!$?)
{
    Write-Host "makensis BoBo.nsi fail"
    "makensis BoBo.nsi failed..." | Add-Content $filename
    return
}
"makensis min finish..." | Add-Content $filename 
"makensis autoupdate start..." | Add-Content $filename 
makensis "/XOutFile $autoPktName" /DPRODUCT_VERSION_MAIN=$mainVer /DPRODUCT_VERSION_SUB=$subVer /DPRODUCT_VERSION_PATCH=$patchVer /DPRODUCT_VERSION_BUILDNO=$buildVer /DAUTO_UPDATE "$installDir\BoBo.nsi"
if(!$?)
{
    Write-Host "makensis BoBo.nsi autoupdate version fail"
    "makensis BoBo.nsi  autoupdate version failed..." | Add-Content $filename
    return
}
"makensis autoupdate finish..." | Add-Content $filename 
"makensis full start..." | Add-Content $filename 
makensis "/XOutFile $fullPktName" /DPRODUCT_VERSION_MAIN=$mainVer /DPRODUCT_VERSION_SUB=$subVer /DPRODUCT_VERSION_PATCH=$patchVer /DPRODUCT_VERSION_BUILDNO=$buildVer /DFULL_VERSION "$installDir\BoBo.nsi"
if(!$?)
{
    Write-Host "makensis BoBo.nsi full version fail"
    return
}
"makensis full finish..." | Add-Content $filename 
if($packThirdParty)
{
	"makensis FxbzThirdParty start..." | Add-Content $filename 
    makensis "$installDir\FxbzThirdParty.nsi"
    if(!$?)
    {
        Write-Host "makensis FxClientThirdParty.nsi fail"
        "makensis FxClientThirdParty.nsi failed..." | Add-Content $filename
        return
    }
	"makensis FxbzThirdParty finish..." | Add-Content $filename 
}
if($signature)
{
    sign (ls "$installDir\*" -Include *.exe)
	"sign finish..." | Add-Content $filename 
}
if($test -or $publish)
{
    # push to git
    $newVer=getProjVer $mainProjDir $mainProjName
	$setupFileMd5=getMd5 $miniPktName
	if($publish)
	{
		git commit -a -m "build publish version:$newVer setupFileMd5:$setupFileMd5 done at $(get-date)"
	}
	else
	{
		git commit -a -m "build release version:$newVer setupFileMd5:$setupFileMd5 done at $(get-date)"
	}
    #git push
	"git push finish..." | Add-Content $filename 
}

Write-Host "build finish"
"build finish..." | Add-Content $filename 

# load base functions
if($uploadFtp)
{
    . $scriptDir\ftpupload.ps1
    $ftpURL = "ftp://ftp.fxwork.kugou.net/pub/mediaclient/FanXingBanZouSetup/build"
    $username = ""
    $userpass = ""
    ftpUpload "$ftpURL/$miniPktName" $username $userpass "$installDir\$miniPktName" $true
    Write-Host "ftpupload1 finish"
    "ftpupload $miniPktName finish..." | Add-Content $filename 
    ftpUpload "$ftpURL/$fullPktName" $username $userpass "$installDir\$fullPktName" $true
    Write-Host "ftpupload2 finish"
    "ftpupload $fullPktName finish..." | Add-Content $filename 
	ftpUpload "$ftpURL/$autoPktName" $username $userpass "$installDir\$autoPktName" $true
    Write-Host "ftpupload3 finish"
    "ftpupload $autoPktName finish..." | Add-Content $filename 
}
