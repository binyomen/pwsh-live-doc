@{
RootModule = "docgen.psm1"
ModuleVersion = "0.1.0"
GUID = "6492c908-8b73-4550-8e95-6c9bf944605e"
Author = "Ben Weedon"
Description = "Helpers for generating pwsh-live-doc HTML"
PowerShellVersion = "7.0"

NestedModules = @(
    "OutputCmdlets.ps1",
    "GeneralizeVersions.ps1",
    "ExesToTest.ps1")

FunctionsToExport = @(
    "OutputPage",
    "OutputText",
    "OutputCode",
    "GetPowerShellExesToTest",
    "GetExeVersion")
}
