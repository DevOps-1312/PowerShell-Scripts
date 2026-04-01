
# ===== PREREQUISITES =====
# 1. Run this script inside a cloned Git repository (not outside repo folder).
# 2. Git must be installed and accessible in system PATH.
# 3. Salesforce CLI (sf) and sfdx-git-delta plugin must be installed.
# 4. ImportExcel PowerShell module must be installed.
# 5. Azure DevOps PAT with Code Read & PR Read permissions is required.
# 6. master branch must represent Production and UAT must contain merged PRs.
# 7. Working directory should be clean (no pending git changes).
# =========================


Import-Module ImportExcel

# ===== USER INPUT =====
$inputExcel     = "Provide your Input PR numbers excel sheet path here"
$outputFolder   = "Provide the folder path where you want to store the generated delta"
$tempBranch     = "temp-release-$(Get-Date -Format yyyyMMddHHmmss)" # Temp release branch name, we re-name it accordingley.
$organizationUrl = "Provide the orginaztion URL"
$projectName     = "Provide the project name"
$repoId          = "Provide the Repo ID"

# ======= User Inputs - 2 =======
$pat = Read-Host "Enter Azure DevOps PAT"
$repoPath = "Provide the local cloned repo path"

if (!(Test-Path "$repoPath\.git")) {
    Write-Host "Invalid Git repository path." -ForegroundColor Red
    exit
}

Set-Location $repoPath


# Create output folder if not exists
if (!(Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Convert PAT to base64
$base64AuthInfo = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes(":$pat")
)

$headers = @{
    Authorization = "Basic $base64AuthInfo"
}

# Read PR list
$prData = Import-Excel $inputExcel
$outputData = @()

Write-Host "Fetching latest code..."
git fetch origin

Write-Host "Switching to master branch..."
git checkout master

Write-Host "Pulling latest master..."
git pull origin master

# Generate unique temp branch name
$tempBranch = "temp-release-$(Get-Date -Format yyyyMMddHHmmss)"

# Delete temp branch if it already exists
if (git branch --list $tempBranch) {
    git branch -D $tempBranch
}

Write-Host "Creating temp branch: $tempBranch"
git checkout -b $tempBranch

foreach ($row in $prData) {

    $prNumber = [int]$row.UATPRs
    Write-Host "`nProcessing PR $prNumber..." -ForegroundColor Cyan
    $status = "Success"

    try {

        $commitUrl = "$organizationUrl/$projectName/_apis/git/repositories/$repoId/pullRequests/$($prNumber)/commits?api-version=7.0"

        $commitResponse = Invoke-RestMethod -Uri $commitUrl -Headers $headers -Method Get

        if (-not $commitResponse.value -or $commitResponse.count -eq 0) {
            throw "No commits found in PR $prNumber"
        }

        foreach ($commit in $commitResponse.value) {

            $commitId = $commit.commitId
            Write-Host "Cherry-picking commit $commitId"

            git cherry-pick $commitId

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Conflict in PR $prNumber at commit $commitId"
                git cherry-pick --abort
                $status = "Conflict"
                break
            }
        }

    }
    catch {
        Write-Warning "Failed PR $prNumber"
        Write-Host $_.Exception.Message -ForegroundColor Red
        $status = "Failed"
    }

    $outputData += [PSCustomObject]@{
        PRNumber = $prNumber
        Status   = $status
    }
}

# ===== Generate Delta Package =====

Write-Host "Generating consolidated package.xml..."

$deltaPath = "$outputFolder\delta"

if (!(Test-Path $deltaPath)) {
    New-Item -ItemType Directory -Path $deltaPath | Out-Null
}

sf sgd source delta `
    --from origin/master `
    --to HEAD `
    --output-dir $deltaPath `
    --generate-delta

# ===== Export PR Status Excel =====

$outputExcel = "$outputFolder\PR_Status.xlsx"
$outputData | Export-Excel -Path $outputExcel -AutoSize

Write-Host "====================================="
Write-Host "✅ Consolidated package.xml generated at $outputFolder"
Write-Host "PR Status File: $outputExcel"
Write-Host "====================================="
