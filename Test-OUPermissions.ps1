<#
.SYNOPSIS
	  This command returns OU permissions specific to Azure AD Connect Hybrid Writeback.

.DESCRIPTION
	  This command will return all the Azure AD Connect Hybrid Writeback permissions on a given OU, and if provided, for a given account in Active Directory, allowing confirmation that permissions have been properly delegated.
	  The command can be just the OU if desired.
   
.PARAMETER Identity
	  UserPrincipalName, SID, ObjectGUID or SamAccountName of a user object in AD

.PARAMETER OU
	  Distinguished Name of the OU that should be the target of the command

.EXAMPLE
        Get-OUPermissions -Identity CN=John Smith,CN=Users,DC=Contoso,DC=com -OU CN=Users,DC=Contoso,DC=com

	Returns a list of all Azure AD Connect Hybrid Writeback permissions for the user John Smith on the Users OU in the Contoso.com domain.

.EXAMPLE
        Get-OUPermissions -OU CN=Users,DC=Contoso,DC=com

	Returns a list of all Azure AD Connect Hybrid Writeback permissions on the Users OU in the Contoso.com domain.

.INPUTS
	Identity, OU

.OUTPUTS
	Report of user permissions

.NOTES
	NAME:	Get-OUPermissions.ps1
	AUTHOR:	Darryl Kegg
	DATE:	01 February, 2018
	EMAIL:	dkegg@microsoft.com

	VERSION HISTORY:
	1.0 01 February, 2018    Initial Version
	2.0 06 February, 2018	 Updated RegEx to accomodate OUs with underscores
							 Updated to Display ALL when permissions are applied to all objects types or propreties
							 Updated to include extended properties and skip CREATOR OWNER permissions

THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
#>

#Requires -Version 3


[CmdletBinding(SupportsShouldProcess = $True)]
param
(
	[Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipeLineByPropertyName = $true)]
	[alias('UserPrincipalName')]
	[alias('objectSID')]
	[alias('objectGUID')]
	[alias('SamAccountName')]
	[alias('DistinguishedName')]
	[string]$Identity,
	[Parameter(Mandatory = $true, HelpMessage = "Full distinguished name of the target OU (e.g. CN=Users,DC=Contoso,DC=Com)")]
	[string]$OU
	# add param for AppliesTo and validate set User,Group,Contact,All
)

Begin
{

	Function Check-IsAdministrator
	{
		$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
		If ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
		{return $true}
		Else
		{return $false}
	}
	
	function Get-ObjectIDInfo ($ObjectID)
	{
		
		if ($objectID -like "*0000-0000-0000*") { return "All" }
		return (Get-ADObject -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter { SchemaIdguid -eq $ObjectID } -Properties LdapDisplayName, SchemaIdGuid).LdapDisplayName
	}
	
	function Get-ExtendedRight ($ExtendedRight)
	{
		return (Get-ADObject -SearchBase (Get-ADRootDSE).ConfigurationNamingContext -Filter { (objectclass -eq "controlAccessRight") -and (rightsguid -eq $ExtendedRight) } -Properties RightsGuid, DisplayName).Displayname
	}
	
}

Process
{
	$OURegExPathTest = '^(?i)(ou=|cn=)[a-zA-Z\d\=\, \-_]*(,dc\=\S*,dc=\S*)|(dc\=\S*,dc=\S*)'
	If ($OU -notmatch $OURegExPathTest)
	{
		Write-Host -ForegroundColor Red "Please verify that the OU path is formatted as ""OU=OrganizationalUnit,DC=domain,dc=tld"" and retry."
		Break
	}
	
	if (!(Check-IsAdministrator))
	{
		Throw "It is necessary to run this command in an elevated PowerShell command prompt, please restart PowerShell in an elevated prompt and try again."
	}
	
	# check for AD PSProvider on system first, if not there, report that this must run on a DC
	Try { $CheckProvider = Get-PSProvider -PSProvider ActiveDirectory -ErrorAction Stop }
	Catch
	{
		Throw "No Active Directory provider found on this system, make sure that you are running this script on a Domain Controller and with sufficient permissions."
	}
	
	if (!(Get-Module ActiveDirectory)) { try { Import-Module ActiveDirectory }
		catch { throw "Unable to load the Active Directory PowerShell module, cannot continue!" }
	}
	
	If (!(Test-Path "AD:\$OU" -ErrorAction SilentlyContinue))
	{ Write-Host -fore Red "The OU - " -NoNewline; Write-Host -fore Yellow "$OU " -nonewline;  Write-Host -fore Red "is not valid, please confirm the OU and try again.";  break }
	
	#Add-WindowsFeature RSAT-AD-PowerShell
	
	# check exchange schema - we wont bother with externalDirectoryObjectID is not Exch 16 or later
	$Schema = (Get-ADRootDSE).SchemaNamingContext
	$Value = "CN=ms-Exch-Schema-Version-Pt," + $Schema
	Try {$ExchangeSchemaVersion = (Get-ADObject $Value -pr rangeUpper).rangeUpper} Catch {$null}
	if ($ExchangeSchemaVersion -lt 15317)
	{ Write-Host -fore Yellow "Note: ms-DS-ExternalDirectoryObjectID not a valid schema attribute for this version of Exchange."}
		
	$aclList = get-acl -path "AD:\$OU" | Select-Object -ExpandProperty Access |
	Where-Object { $_.IdentityReference -notmatch "builtin|AUTHORITY|admins|Exchange|Organization|everyone|delegated|creator"} |
	Where-Object { ($_.ActiveDirectoryRights -eq "WriteProperty") } |
	Where-Object { $_.IdentityReference -like "*$Identity*" }
	
	$extendedRights = get-acl -path "AD:\$OU" | Select-Object -ExpandProperty Access |
	Where-Object { $_.IdentityReference -notmatch "builtin|AUTHORITY|admins|Exchange|Organization|everyone|delegated|creator" } |
	Where-Object { ($_.ActiveDirectoryRights -eq "ExtendedRight") } |
	Where-Object { $_.IdentityReference -like "*$Identity*" }
	
	if ($aclList)
	{
		$aclList | Format-Table @{ n = "User"; E = { ($_.IdentityReference).value.split('\')[1] } }, @{ n = "Access"; e = { $_.AccessControlType } }, IsInherited, @{ n = "Rights"; e = { $_.ActiveDirectoryRights } }, @{ n = "Attribute"; e = { Get-ObjectIDInfo $_.ObjectType } }, @{ n = "AppliedTo"; e = { Get-ObjectIDInfo $_.InheritedObjectType } } -Auto
	}
	else
	{ Write-Host -fore Yellow "`nNo ACL entries found." }
	
	if ($extendedRights)
	{
		$extendedRights | Format-Table @{ n = "User"; E = { ($_.IdentityReference).value.split('\')[1] } }, @{ n = "Access"; e = { $_.AccessControlType } }, IsInherited, @{ n = "Rights"; e = { $_.ActiveDirectoryRights } }, @{ n = "Extended Property"; e = { Get-ExtendedRight $_.ObjectType } } -Auto
	}
	else
	{ Write-Host -fore Yellow "`nNo extended rights found." }
}

