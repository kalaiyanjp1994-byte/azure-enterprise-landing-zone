targetScope = 'subscription'

param location string  = 'eastus'

// 1. Policy: Enforce Resource Location
var locationPolicyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'

resource locationAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'policy-enforce-location'
  properties: {
    policyDefinitionId: locationPolicyDefinitionId
    parameters: {
      listOfAllowedLocations: {
        value: [
          location
        ]
      }
    }
  }
}

// 2. Policy: Require Tag on Resources (CostCenter)
var tagPolicyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99'

resource tagAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'policy-require-costcenter-tag'
  properties: {
    policyDefinitionId: tagPolicyDefinitionId
    parameters: {
      tagName: {
        value: 'CostCenter'
      }
    }
  }
}


