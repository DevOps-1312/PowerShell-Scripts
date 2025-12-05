# Extract All Repos - GitHub Organization Repository Extractor

if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Force -Scope CurrentUser
}
# Load necessary module
Import-Module ImportExcel
# === User Inputs ===
$inputFilePath = "input_orgs.xlsx"  # Input Excel file with organization names
$outputFilePath = "output_repos.xlsx"  # Output Excel file for repository list
$githubToken = "access token"  # Replace with your GitHub access token

# Read organization names from input Excel
$orgs = Import-Excel -Path $inputFilePath -WorksheetName 'Sheet1'
# Store results
$results = @()
foreach ($org in $orgs) {
    $orgName = $org.OrganizationName
    Write-Output "Fetching repos for organization: $orgName"
    $headers = @{
        Authorization = "token $githubToken"
        Accept        = "application/vnd.github+json"
    }
    $page = 1
    $hasMore = $true
    while ($hasMore) {
        $uri = "https://api.github.com/orgs/$orgName/repos?per_page=100&page=$page"
        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
            if ($response.Count -eq 0) {
                $hasMore = $false
            } else {
                foreach ($repo in $response) {
                    $results += [PSCustomObject]@{
                        Organization = $orgName
                        Repository   = $repo.name
                    }
                }
                $page++
            }
        } catch {
            Write-Warning "Failed to fetch repos for organization: $orgName. Error: $_"
            $hasMore = $false
        }
    }
}
# Export results to Excel
$results | Export-Excel -Path $outputFilePath -AutoSize -WorksheetName "OrgRepos"
Write-Host "Repository list exported to $outputFilePath"

# Extract All Repos - GitHub Organization Repository Extractor

## Overview
# This PowerShell script automates the process of extracting all repositories from GitHub organizations and exporting them to an Excel file. 
# It's designed to help DevOps engineers and GitHub administrators quickly inventory repositories across multiple organizations.

## Prerequisites
# Before running this script, ensure you have:

# - **PowerShell 5.1 or higher** (Windows built-in)
# - **ImportExcel Module** (installed automatically by the script)
# - **GitHub Personal Access Token** (GitHub account required)
# - **Input Excel File** (`input_orgs.xlsx`) with organization names
# - **Administrator privileges** (may be needed for module installation)

## Configuration
# Edit the script and update these variables:

# ```powershell
# $inputFilePath = "input_orgs.xlsx"      # Path to input Excel file
# $outputFilePath = "output_repos.xlsx"   # Path to output Excel file
# $githubToken = "your_token_here"        # Your GitHub Personal Access Token
# ```

# **⚠️ Security Warning**: Never commit the token to Git. 
# Use environment variables or Azure Key Vault for production.