# <copyright file="powerbi.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Power BI properties for shared cloud connections.
$powerBIconfig = "./pbiconfig/config.yaml"

# Synopsis: Deploys the specified shared cloud connections to the Power BI Service.
$cloudConnection = @(
    # @{ 
    # displayName = "jess-demo-cloud-connection"
    # connectionType = "AzureBlobs"
    # parameters = @(
    #     @{
    #         dataType = "Text"
    #         name = "domain"
    #         value = "blob.core.windows.net"
    #     }
    #     @{
    #         dataType = "Text"
    #         name = "account"
    #         value = "pbicloudconnection"  
    #     }
    # )
    # servicePrincipalClientId = $app.AppId
    # servicePrincipalSecret = $cred.SecretText | ConvertTo-SecureString -AsPlainText
    # tenantId = "0f621c67-98a0-4ed5-b5bd-31a35be41e29"
    # }
)