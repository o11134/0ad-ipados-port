[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script:PassCount = 0
$script:WarnCount = 0
$script:FailCount = 0
$script:SkipCount = 0

function Write-Pass([string]$Message)
{
	$script:PassCount++
	Write-Output "PASS: $Message"
}

function Write-Warn([string]$Message)
{
	$script:WarnCount++
	Write-Output "WARN: $Message"
}

function Write-Fail([string]$Message)
{
	$script:FailCount++
	Write-Error "FAIL: $Message" -ErrorAction Continue
}

function Write-Skip([string]$Message)
{
	$script:SkipCount++
	Write-Output "SKIP: $Message"
}

function Get-RelativePath([string]$Path)
{
	return $Path.Substring($RepositoryRoot.Length + 1).Replace('\', '/')
}

$requiredFiles = @(
	'.github/workflows/ipados-m2.yml',
	'build/ios/CMakeLists.txt',
	'build/ios/IOSBuildConfig.h.in',
	'build/ios/Info.plist.in',
	'docs/ipados/GITHUB_ACTIONS.md',
	'docs/ipados/MAC_HANDOFF.md',
	'docs/ipados/M2_FILE_INVENTORY.md',
	'scripts/ios/run-ci-simulator-smoke.sh',
	'scripts/ios/run-static-checks.sh',
	'scripts/ios/verify-mac-environment.sh',
	'source/platform/ios/main.mm',
	'source/platform/ios/IOSAppDelegate.mm',
	'source/platform/ios/IOSSceneDelegate.mm',
	'source/platform/ios/IOSViewController.mm',
	'source/platform/ios/IOSPlatformBridge.mm'
)
$missingFiles = @($requiredFiles | Where-Object {
	-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot $_) -PathType Leaf)
})
if ($missingFiles.Count -eq 0)
{
	Write-Pass 'required M2 source, build, CI, script, and documentation files are present'
}
else
{
	Write-Fail ('required files are missing: ' + ($missingFiles -join ', '))
}

$shellPath = $null
$shellCommand = Get-Command sh -ErrorAction SilentlyContinue
if ($shellCommand)
{
	$shellPath = $shellCommand.Source
}
else
{
	$gitCommand = Get-Command git -ErrorAction SilentlyContinue
	if ($gitCommand)
	{
		$gitRoot = Split-Path (Split-Path $gitCommand.Source -Parent) -Parent
		$gitShellCandidate = Join-Path $gitRoot 'usr\bin\sh.exe'
		if (Test-Path -LiteralPath $gitShellCandidate -PathType Leaf)
		{
			$shellPath = $gitShellCandidate
		}
	}
}
if ($shellPath)
{
	$shellFailed = $false
	Push-Location $RepositoryRoot
	try
	{
		Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'scripts\ios') -Filter '*.sh' |
			Sort-Object Name | ForEach-Object {
				$relativeScript = 'scripts/ios/' + $_.Name
				& $shellPath -n $relativeScript
				if ($LASTEXITCODE -ne 0)
				{
					$shellFailed = $true
				}
			}
	}
	finally
	{
		Pop-Location
	}
	if ($shellFailed)
	{
		Write-Fail 'one or more scripts/ios shell files have invalid syntax'
	}
	else
	{
		Write-Pass 'shell syntax is valid for every scripts/ios/*.sh file'
	}
}
else
{
	Write-Skip 'shell syntax check unavailable because no POSIX sh was found'
}

$workflowPath = Join-Path $RepositoryRoot '.github\workflows\ipados-m2.yml'
$workflowLines = [System.IO.File]::ReadAllLines($workflowPath)
$workflowText = [System.IO.File]::ReadAllText($workflowPath)
$yamlStructureErrors = @()
$blockScalarParentIndent = $null
for ($lineIndex = 0; $lineIndex -lt $workflowLines.Count; $lineIndex++)
{
	$line = $workflowLines[$lineIndex]
	$lineNumber = $lineIndex + 1
	if ($line.Contains("`t"))
	{
		$yamlStructureErrors += "line ${lineNumber}: tab indentation"
		continue
	}
	if ($line -match '^\s*$' -or $line -match '^\s*#')
	{
		continue
	}
	$indent = $line.Length - $line.TrimStart(' ').Length
	if ($null -ne $blockScalarParentIndent -and $indent -gt $blockScalarParentIndent)
	{
		continue
	}
	$blockScalarParentIndent = $null
	if (($indent % 2) -ne 0)
	{
		$yamlStructureErrors += "line ${lineNumber}: indentation is not a multiple of two"
	}
	$trimmed = $line.TrimStart(' ')
	if ($trimmed.StartsWith('- '))
	{
		continue
	}
	if ($trimmed -notmatch '^[A-Za-z0-9_.-]+:\s*(.*)$')
	{
		$yamlStructureErrors += "line ${lineNumber}: unsupported or malformed mapping entry"
		continue
	}
	if ($Matches[1] -match '^[|>]')
	{
		$blockScalarParentIndent = $indent
	}
}
if ($yamlStructureErrors.Count -eq 0)
{
	Write-Pass 'workflow YAML subset grammar and indentation are structurally valid on Windows'
}
else
{
	$yamlStructureErrors | ForEach-Object { Write-Output $_ }
	Write-Fail 'workflow YAML structure is invalid'
}

if ($shellPath)
{
	$workflowRunBlocks = @()
	for ($lineIndex = 0; $lineIndex -lt $workflowLines.Count; $lineIndex++)
	{
		if ($workflowLines[$lineIndex] -notmatch '^(\s*)run:\s*\|\s*$')
		{
			continue
		}
		$parentIndent = $Matches[1].Length
		$contentIndent = $parentIndent + 2
		$blockLines = @()
		for ($blockIndex = $lineIndex + 1; $blockIndex -lt $workflowLines.Count; $blockIndex++)
		{
			$blockLine = $workflowLines[$blockIndex]
			$blockLineIndent = $blockLine.Length - $blockLine.TrimStart(' ').Length
			if ($blockLine.Trim().Length -gt 0 -and $blockLineIndent -le $parentIndent)
			{
				break
			}
			if ($blockLine.Trim().Length -eq 0)
			{
				$blockLines += ''
			}
			elseif ($blockLine.Length -ge $contentIndent)
			{
				$blockLines += $blockLine.Substring($contentIndent)
			}
			else
			{
				$blockLines += $blockLine
			}
		}
		$workflowRunBlocks += ($blockLines -join "`n")
	}

	$workflowShellFailed = $false
	for ($blockNumber = 0; $blockNumber -lt $workflowRunBlocks.Count; $blockNumber++)
	{
		$blockText = $workflowRunBlocks[$blockNumber]
		$blockText | & $shellPath -n
		if ($LASTEXITCODE -ne 0)
		{
			Write-Output "workflow run block $($blockNumber + 1) has invalid shell syntax"
			$workflowShellFailed = $true
		}
	}
	if ($workflowShellFailed)
	{
		Write-Fail 'one or more workflow run blocks have invalid shell syntax'
	}
	else
	{
		Write-Pass "all $($workflowRunBlocks.Count) workflow run blocks have valid shell syntax"
	}
}
else
{
	Write-Skip 'workflow run-block shell syntax check unavailable because no POSIX sh was found'
}

$requiredWorkflowFragments = @(
	'name: iPadOS M2 Scaffold',
	'workflow_dispatch:',
	'push:',
	'pull_request:',
	'contents: read',
	'cancel-in-progress: true',
	'runs-on: macos-15',
	'timeout-minutes: 45',
	'CODE_SIGNING_ALLOWED=NO',
	'if: ${{ always() }}',
	'retention-days: 14'
)
$missingWorkflowFragments = @($requiredWorkflowFragments | Where-Object {
	-not $workflowText.Contains($_)
})
if ($missingWorkflowFragments.Count -eq 0)
{
	Write-Pass 'workflow triggers, permissions, runner, timeout, signing-off, always-upload, and retention fields are present'
}
else
{
	Write-Fail ('workflow structure is missing: ' + ($missingWorkflowFragments -join ', '))
}

$usesLines = @(Select-String -LiteralPath $workflowPath -Pattern '^\s+uses:')
$pinnedOfficialActionLines = @($usesLines | Where-Object {
	$_.Line -match '^\s+uses: actions/(checkout|upload-artifact)@[0-9a-f]{40}(\s+#.*)?$'
})
if ($usesLines.Count -eq 2 -and $pinnedOfficialActionLines.Count -eq 2)
{
	Write-Pass 'workflow uses only two official GitHub actions pinned to immutable commit SHAs'
}
else
{
	Write-Fail 'workflow action references are not the expected pinned official actions'
}

$workflowForbiddenPattern = 'secrets\.|DEVELOPMENT_TEAM[^\r\n]*[=:]\s*["'']?[A-Z0-9]{10}([^A-Z0-9]|$)|PROVISIONING_PROFILE|CODE_SIGN_IDENTITY|git\s+lfs\s+(pull|fetch)|(^|\s)(curl|wget)(\s|$)|git\s+(reset\s+--hard|clean|stash|rebase|push\s+--force)'
$workflowForbidden = @(Select-String -LiteralPath $workflowPath -Pattern $workflowForbiddenPattern)
if ($workflowForbidden.Count -eq 0)
{
	Write-Pass 'workflow contains no secret reference, signing identity, downloader, LFS hydration, or destructive Git command'
}
else
{
	$workflowForbidden | ForEach-Object { Write-Output "$($_.LineNumber):$($_.Line.Trim())" }
	Write-Fail 'workflow contains a forbidden secret, signing, download, LFS, or Git pattern'
}

$cmakeForWorkflow = [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot 'build\ios\CMakeLists.txt'))
$appDelegateForWorkflow = [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot 'source\platform\ios\IOSAppDelegate.mm'))
$viewControllerForWorkflow = [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot 'source\platform\ios\IOSViewController.mm'))
$simulatorScriptForWorkflow = [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts\ios\run-ci-simulator-smoke.sh'))
if ($cmakeForWorkflow.Contains('set(CMAKE_XCODE_GENERATE_SCHEME ON)') -and
	$appDelegateForWorkflow.Contains('M2_SHELL_LAUNCHED') -and
	$viewControllerForWorkflow.Contains('M2_SANDBOX_PROBE_PASS') -and
	$viewControllerForWorkflow.Contains('M2_SANDBOX_PROBE_FAIL') -and
	$simulatorScriptForWorkflow.Contains('processID == $APP_PID'))
{
	Write-Pass 'deterministic Xcode scheme and launched-process simulator smoke markers are wired'
}
else
{
	Write-Fail 'Xcode scheme or simulator smoke marker wiring is incomplete'
}

try
{
	[void][xml](Get-Content -LiteralPath (Join-Path $RepositoryRoot 'build\ios\Info.plist.in') -Raw)
	Write-Pass '.NET XML parser accepts Info.plist.in'
	Write-Skip 'Apple plutil is unavailable on this Windows host; .NET provided XML-only validation'
}
catch
{
	Write-Fail ('Info.plist.in is not well-formed XML: ' + $_.Exception.Message)
}

$targetRoots = @(
	'build\ios',
	'docs\ipados',
	'libraries\ios',
	'scripts\ios',
	'source\platform\ios'
) | ForEach-Object { Join-Path $RepositoryRoot $_ }
$allFiles = @(Get-ChildItem -LiteralPath $targetRoots -Recurse -File |
	Where-Object {
		$_.FullName -notmatch '\\build\\ios\\(out|generated|DerivedData)\\' -and
		$_.FullName -notmatch '\\xcuserdata\\' -and
		$_.FullName -notmatch '\\libraries\\ios\\(build|downloads|output)\\'
	} | Sort-Object FullName)
$allFiles = @($allFiles + (Get-Item -LiteralPath $workflowPath) | Sort-Object FullName)
$scanFiles = @($allFiles | Where-Object {
	$_.Name -notin @('run-static-checks.sh', 'run-static-checks.ps1')
})

$nulFiles = @()
$trailingWhitespace = @()
foreach ($file in $allFiles)
{
	if ([System.IO.File]::ReadAllBytes($file.FullName) -contains 0)
	{
		$nulFiles += Get-RelativePath $file.FullName
	}
	$matches = @(Select-String -LiteralPath $file.FullName -Pattern '[ \t]+$')
	foreach ($match in $matches)
	{
		$trailingWhitespace += "$(Get-RelativePath $file.FullName):$($match.LineNumber)"
	}
}
if ($nulFiles.Count -eq 0 -and $trailingWhitespace.Count -eq 0)
{
	Write-Pass 'target files contain no NUL bytes or trailing whitespace'
}
else
{
	if ($nulFiles.Count -gt 0) { Write-Output ('NUL: ' + ($nulFiles -join ', ')) }
	if ($trailingWhitespace.Count -gt 0) { Write-Output ('trailing whitespace: ' + ($trailingWhitespace -join ', ')) }
	Write-Fail 'NUL byte or trailing whitespace found'
}

$unbalancedMarkdown = @()
Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'docs\ipados') -Filter '*.md' | ForEach-Object {
	$fenceCount = @(Select-String -LiteralPath $_.FullName -Pattern '^```').Count
	if (($fenceCount % 2) -ne 0)
	{
		$unbalancedMarkdown += Get-RelativePath $_.FullName
	}
}
if ($unbalancedMarkdown.Count -eq 0)
{
	Write-Pass 'Markdown code fences are balanced'
}
else
{
	Write-Fail ('unbalanced Markdown code fences: ' + ($unbalancedMarkdown -join ', '))
}

$scanDefinitions = @(
	@{
		Name = 'hard-coded user, Homebrew, or host-specific absolute path'
		Pattern = '(?<![A-Za-z0-9])[A-Za-z]:\\|/(Users|home)/|/opt/homebrew/|/usr/local/'
		Files = $scanFiles
	},
	@{
		Name = 'private key or common credential pattern'
		Pattern = 'BEGIN ([A-Z ]+ )?PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}'
		Files = $scanFiles
	},
	@{
		Name = 'hard-coded Apple Development Team value'
		Pattern = 'DEVELOPMENT_TEAM[^\r\n]*[=:]\s*["'']?[A-Z0-9]{10}([^A-Z0-9]|$)'
		Files = @($scanFiles | Where-Object { $_.FullName -notlike '*libraries\ios*' })
	},
	@{
		Name = 'private or prohibited runtime primitive in the M2 build scope'
		Pattern = 'performSelector|NSClassFromString|(?<![A-Za-z0-9_])(dlopen|dlsym|fork|popen|system)\s*\(|allow-unsigned-executable-memory'
		Files = @($scanFiles | Where-Object { $_.FullName -notlike '*docs\ipados*' })
	}
)
foreach ($definition in $scanDefinitions)
{
	$found = $false
	foreach ($file in $definition.Files)
	{
		foreach ($match in @(Select-String -LiteralPath $file.FullName -Pattern $definition.Pattern))
		{
			Write-Output "$(Get-RelativePath $file.FullName):$($match.LineNumber):$($match.Line.Trim())"
			$found = $true
		}
	}
	if ($found)
	{
		Write-Fail ($definition.Name + ' found')
	}
	else
	{
		Write-Pass ('no ' + $definition.Name + ' found')
	}
}

$handoffText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'docs\ipados\MAC_HANDOFF.md') -Raw
if ($handoffText.Contains('/Applications/Xcode.app/Contents/Developer'))
{
	Write-Warn 'MAC_HANDOFF.md intentionally names the standard Xcode.app developer directory; verify it locally'
}

$m2BuildFiles = @($scanFiles | Where-Object {
	$_.FullName -like '*build\ios*' -or $_.FullName -like '*source\platform\ios*'
})
$networkFound = $false
foreach ($file in $m2BuildFiles)
{
	foreach ($match in @(Select-String -LiteralPath $file.FullName -Pattern 'NSURLSession|NWConnection|CFNetwork|UIWebView|WKWebView|NSAllowsArbitraryLoads|UIBackgroundModes|com\.apple\.developer\.networking'))
	{
		Write-Output "$(Get-RelativePath $file.FullName):$($match.LineNumber):$($match.Line.Trim())"
		$networkFound = $true
	}
}
if ($networkFound)
{
	Write-Fail 'network, web-view, or background-mode API/configuration found in M2'
}
else
{
	Write-Pass 'M2 build and source contain no scanned network, web-view, or background-mode API/configuration'
}

$remoteFound = $false
Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'scripts\ios') -File |
	Where-Object { $_.Name -notin @('run-static-checks.sh', 'run-static-checks.ps1') } |
	ForEach-Object {
		foreach ($match in @(Select-String -LiteralPath $_.FullName -CaseSensitive -Pattern '(^|\s)(curl|wget|git\s+lfs)(\s|$)|Invoke-WebRequest|https?://'))
		{
			Write-Output "$(Get-RelativePath $_.FullName):$($match.LineNumber):$($match.Line.Trim())"
			$remoteFound = $true
		}
	}
if ($remoteFound)
{
	Write-Fail 'download, remote script, or Git LFS command found in scripts/ios'
}
else
{
	Write-Pass 'scripts/ios contain no download, remote script, or Git LFS command'
}

$patchFile1 = Join-Path $RepositoryRoot 'patches\upstream\0001-sysdep-detect-ios-platform.patch'
$patchFile2 = Join-Path $RepositoryRoot 'patches\upstream\0002-timer-include-sys-time.patch'
$patchFile3 = Join-Path $RepositoryRoot 'patches\upstream\0003-unix-ios-portability.patch'
$patchFile4 = Join-Path $RepositoryRoot 'patches\upstream\0004-ios-executable-path.patch'
$applyScript = Join-Path $RepositoryRoot 'scripts\ios\apply-upstream-patches.sh'
if ((Test-Path -LiteralPath $patchFile1) -and
	(Test-Path -LiteralPath $patchFile2) -and
	(Test-Path -LiteralPath $patchFile3) -and
	(Test-Path -LiteralPath $patchFile4) -and
	(@(Select-String -LiteralPath $patchFile2 -SimpleMatch 'sys/time.h').Count -gt 0) -and
	(@(Select-String -LiteralPath $patchFile3 -SimpleMatch 'OS_IOS').Count -gt 0) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch 'diff --git a/source/lib/sysdep/os/ios/ios.cpp b/source/lib/sysdep/os/ios/ios.cpp').Count -eq 1) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch 'new file mode 100644').Count -eq 1) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch '--- /dev/null').Count -eq 1) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch '+++ b/source/lib/sysdep/os/ios/ios.cpp').Count -eq 1) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch '+OsPath sys_ExecutablePathname()').Count -eq 1) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch '_NSGetExecutablePath').Count -gt 0) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch 'realpath').Count -gt 0) -and
	(@(Select-String -LiteralPath $patchFile4 -SimpleMatch 'PATH_MAX').Count -eq 0) -and
	(@(Select-String -LiteralPath $applyScript -SimpleMatch 'apply --check').Count -gt 0) -and
	(@(Select-String -LiteralPath $applyScript -SimpleMatch '/*.patch').Count -gt 0) -and
	(@(Select-String -LiteralPath $applyScript -SimpleMatch '--3way').Count -eq 0) -and
	(@(Select-String -LiteralPath $applyScript -SimpleMatch 'fuzzy').Count -eq 0) -and
	(@(Select-String -LiteralPath $applyScript -SimpleMatch 'patch -F').Count -eq 0))
{
	Write-Pass 'upstream patching is deterministic and unified-diff based'
}
else
{
	Write-Fail 'deterministic unified patching checks failed'
}

$coreCmakeFile = Join-Path $RepositoryRoot 'build\ios\core\CMakeLists.txt'
$coreProbeFile = Join-Path $RepositoryRoot 'source\platform\probe\CoreProbe.mm'
$coreWorkflowFile = Join-Path $RepositoryRoot '.github\workflows\ipados-m3-core.yml'
if ((Test-Path -LiteralPath $coreCmakeFile) -and
	(Test-Path -LiteralPath $coreProbeFile) -and
	(Test-Path -LiteralPath $coreWorkflowFile) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'timer.cpp').Count -gt 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'module_init.cpp').Count -gt 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/wsecure_crt.cpp').Count -eq 1) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/fnv_hash.cpp').Count -eq 1) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/sysdep/os/osx/odbg.cpp').Count -eq 1) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/sysdep/os/ios/ios.cpp').Count -eq 1) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/sysdep/os/osx/osx.cpp').Count -eq 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/sysdep/os/osx/osx_bundle.mm').Count -eq 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/sysdep/os/linux/ldbg.cpp').Count -eq 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'source/lib/sysdep/os/bsd/bdbg.cpp').Count -eq 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'CONFIG_ENABLE_PCH=0').Count -eq 1) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'target_link_libraries(PyrogenesisCoreIOS').Count -eq 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -Pattern '(?i)(fmt|boost|sdl|mozjs|spidermonkey|moltenvk|vulkan|openal|enet|vfs|renderer|network)').Count -eq 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch '"-framework ').Count -eq 2) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch '"-framework Foundation"').Count -eq 1) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch '"-framework UIKit"').Count -eq 1) -and
	(@(Select-String -LiteralPath $coreWorkflowFile -SimpleMatch 'otool -L').Count -gt 0) -and
	(@(Select-String -LiteralPath $coreWorkflowFile -SimpleMatch 'nm -u').Count -gt 0) -and
	(@(Select-String -LiteralPath $coreCmakeFile -SimpleMatch 'GameSetup.cpp').Count -eq 0))
{
	Write-Pass 'M3-C1 core probe CMake, probe source, and workflow configuration are valid'
}
else
{
	Write-Fail 'M3-C1 core probe static checks failed'
}

$cmakeText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'build\ios\CMakeLists.txt') -Raw
if ($cmakeText.Contains('set(IPADOS_BUNDLE_IDENTIFIER "org.example.pyrogenesis.ipadshell"') -and
	$cmakeText.Contains('set(IPADOS_PRODUCT_NAME "Pyrogenesis iPad Shell"'))
{
	Write-Pass 'temporary bundle identifier and product-name defaults are exact'
}
else
{
	Write-Fail 'temporary bundle identifier or product-name default differs from the reviewed value'
}

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and (& git -C $RepositoryRoot rev-parse --git-dir 2>$null))
{
	$ignoreFailed = $false
	$ignoredPaths = @(
		'build/ios/out/probe',
		'build/ios/generated/probe.h',
		'build/ios/DerivedData/probe',
		'build/ios/Probe.xcodeproj/xcuserdata/probe',
		'build/ios/Probe.xcodeproj/project.xcworkspace/xcuserdata/probe.xcuserstate',
		'libraries/ios/downloads/probe',
		'libraries/ios/build/device/probe',
		'libraries/ios/output/device/probe'
	)
	foreach ($ignoredPath in $ignoredPaths)
	{
		& git -C $RepositoryRoot check-ignore -q --no-index -- $ignoredPath
		if ($LASTEXITCODE -ne 0)
		{
			Write-Output "not ignored: $ignoredPath"
			$ignoreFailed = $true
		}
	}
	if ($ignoreFailed)
	{
		Write-Fail 'one or more generated/output probes are not ignored'
	}
	else
	{
		Write-Pass 'generated project, user state, DerivedData, download, build, and output probes are ignored'
	}

	$untrackedScripts = @(& git -C $RepositoryRoot ls-files --others --exclude-standard -- scripts/ios)
	if ($untrackedScripts.Count -gt 0)
	{
		Write-Warn 'iOS scripts are untracked; invoke them through sh until executable modes are recorded in a reviewed commit'
	}
}
else
{
	Write-Skip 'Git ignore behavior could not be checked'
}

$cmake = Get-Command cmake -ErrorAction SilentlyContinue
$osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
if (-not $cmake)
{
	Write-Skip 'CMake syntax/configure check unavailable because CMake is not installed'
}
elseif ($osDescription -notmatch 'Darwin|macOS')
{
	Write-Skip 'CMake Xcode configure is Apple-host-only; CMake was not asked to fake an iPadOS build'
}
else
{
	Write-Skip 'run scripts/ios/run-static-checks.sh on macOS for the isolated Xcode/CMake configure check'
}

Write-Output "SUMMARY: PASS=$script:PassCount WARN=$script:WarnCount FAIL=$script:FailCount SKIP=$script:SkipCount"
Write-Output 'NOTE: static checks do not prove Objective-C++ compilation, signing, simulator launch, or device launch.'

if ($script:FailCount -ne 0)
{
	exit 1
}
