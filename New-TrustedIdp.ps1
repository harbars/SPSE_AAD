# Sample to setup the Trusted IDP in SP for Azure AD.
Add-PSSnapin -Name "Microsoft.SharePoint.Powershell"

# Update these variables as neccessary
$SPTrustedIdpName = "Azure AD (harbars.onmicrosoft.com)"
$SPTrustedIdpDescription = "Allow users within the harbars.onmicrosoft.com Azure AD tenant to sign in"

# Base64 SAML Signing Certificate downloaded from Azure AD Enterprise Application Single Sign On page
$SamlSigningCertificatePath ="C:\PublicCertificate.cer" 

# The Login URL copied from the Enterprise Application Single Sign On Page
# e.g. https://login.microsoftonline.com/67c7a1aa-d528-4f01-87a5-3427a4ab01a4/saml2 
# with saml2 replaced with wsfed              
$SignInUrl="https://login.microsoftonline.com/67c7a1aa-d528-4f01-87a5-3427a4ab01a4/wsfed"           


# Only change below if you need to extend Claims Mappings
$Realm = "urn:sharepoint:federation"
$ClaimTypeRoot = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims"
$Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SamlSigningCertificatePath)

# Creates Trust
New-SPTrustedRootAuthority -Name $SPTrustedIdpName -Certificate $Certificate
# ***** Trust

# Basic claims mappings, extend as neccessary
$ClaimMapping1 = New-SPClaimTypeMapping -IncomingClaimType "$ClaimTypeRoot/name" -IncomingClaimTypeDisplayName "name" -LocalClaimType "$ClaimTypeRoot/upn"
$ClaimMapping2 = New-SPClaimTypeMapping -IncomingClaimType "$ClaimTypeRoot/givenname" -IncomingClaimTypeDisplayName "GivenName" -SameAsIncoming
$ClaimMapping3 = New-SPClaimTypeMapping -IncomingClaimType "$ClaimTypeRoot/surname" -IncomingClaimTypeDisplayName "SurName" -SameAsIncoming
$ClaimMapping4 = New-SPClaimTypeMapping -IncomingClaimType "$ClaimTypeRoot/emailaddress" -IncomingClaimTypeDisplayName "Email" -SameAsIncoming

# Create Trusted Idp
$SPTrustedIdp = New-SPTrustedIdentityTokenIssuer -Name $SPTrustedIdpName -Description $SPTrustedIdpDescription -realm $Realm `
                                                 -SignInUrl $SignInUrl -IdentifierClaim "$ClaimTypeRoot/name" -ImportTrustCertificate $Certificate `
                                                 -ClaimsMappings $ClaimMapping1,$ClaimMapping2,$ClaimMapping3,$ClaimMapping4
# ***** Trusted IDP



# Get it again (for demo, normally you'd do it upfront)
$SPTrustedIdp = Get-SPTrustedIdentityTokenIssuer $SPTrustedIdpName
# Support multiple web apps
$SPTrustedIdp.UseWReplyParameter=$true
$SPTrustedIdp.Update()
# ***** Multiple Web Apps



# Deplpoy the AzureCP WSP (already ran Add-SPSolution)
Install-SPSolution -Identity "AzureCP.wsp" -GACDeployment -force
Restart-Service SPTimerV4

# Connect the Claims Provider to the Trusted Idp
$SPTrustedIdp = Get-SPTrustedIdentityTokenIssuer $SPTrustedIdpName
$SPTrustedIdp.ClaimProviderName = "AzureCP"
$SPTrustedIdp.Update()
# we don't care about the update conflict!



# clean up
Get-SPTrustedIdentityTokenIssuer | Remove-SPTrustedIdentityTokenIssuer
Remove-SPTrustedRootAuthority $SPTrustedIdpName

#EOF