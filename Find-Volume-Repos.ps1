# Requires ImportExcel module
# Install it if not available:
# Install-Module -Name ImportExcel -Force
Import-Module ImportExcel
# === Prompt for GitHub Personal Access Token ===
$githubToken = Read-Host "Enter your GitHub Personal Access Token"
# === Configuration ===
$inputExcelPath = "Org_List.xlsx"      # Input Excel containing 'Organization' column
$outputExcelPath = "output_org_size.xlsx"
# === Setup Headers ===
$headers = @{
    Authorization = "token $githubToken"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}
# === Read Input Organizations ===
$inputData = Import-Excel -Path $inputExcelPath -WorksheetName 'Sheet2'
$outputData = @()
# === Function: Get all paginated repositories ===
function Get-AllRepos {
    param (
        [string]$org,
        [hashtable]$headers
    )
    $allRepos = @()
    $page = 1
    $perPage = 100
    do {
        $url = "https://api.github.com/orgs/$org/repos?per_page=$perPage&page=$page"
        Write-Host "Fetching page $page for $org ..." -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            if ($response.Count -gt 0) {
                $allRepos += $response
                $page++
            } else {
                break
            }
        } catch {
            Write-Warning "Error fetching page $page for $org - $_"
            break
        }
    } while ($true)
    return $allRepos
}
# === Process Each Organization ===
foreach ($row in $inputData) {
    $org = $row.OrganizationName
    Write-Host "`n🔍 Checking organization: $org" -ForegroundColor Yellow
    try {
        $repos = Get-AllRepos -org $org -headers $headers
        $totalSizeKB = 0
        foreach ($repo in $repos) {
            $totalSizeKB += [int]$repo.size
        }
        $totalSizeMB = [math]::Round($totalSizeKB / 1024, 2)
        $totalSizeGB = [math]::Round($totalSizeKB / (1024 * 1024), 2)
        $outputData += [PSCustomObject]@{
            Organization  = $org
            Repo_Count    = $repos.Count
            Total_Size_MB = $totalSizeMB
            Total_Size_GB = $totalSizeGB
        }
        Write-Host "✅ $org - $($repos.Count) repos - $totalSizeGB GB total" -ForegroundColor Green
    } catch {
        Write-Warning "Error processing organization $org - $_"
        $outputData += [PSCustomObject]@{
            Organization  = $org
            Repo_Count    = "Error"
            Total_Size_MB = "Error"
            Total_Size_GB = "Error"
        }
    }
}
# === Export to Excel ===
$outputData | Export-Excel -Path $outputExcelPath -AutoSize -WorksheetName "OrgSizes"
Write-Host "'Output written to: $outputExcelPath" -ForegroundColor Green