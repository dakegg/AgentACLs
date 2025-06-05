# AgentACLs
Scripts to support the ACLing of AD service accounts for a Source AD management agent.

**SETTING THE PERMISSIONS**

Run the command Set-ServiceAccountPermissions.ps1 using the -Identity switch for the SamAccountName of the service account, and the -OU switch for the OU where writeback permissions need to be applied.  

**NOTE**: It's recommended you apply the permissions at the TOP level of your forest (eg. DC=Contoso,DC=Com)

![image](https://github.com/user-attachments/assets/1e99ae22-9e4b-4ee9-afd7-298ee3394fb5)

** It's strongly recommended to wait 15+ minutes before running the test command below, to provide time for AD replication to complete.

**TESTING THE NEW PERMISSIONS**

Simply run the _Test-OUPermissions.ps1_ PowerShell script with the -OU command and provide an OU that you want to check as well as the SamAccountName of the service account to check.

The output from the command should display the service account you provided, along with a list of all permissions delegated at the OU specified with the **-OU** switch

![image](https://github.com/user-attachments/assets/223596b4-58c6-44e6-a7f1-673d3eeb3cd7)


**NOTE**: It will show Inherited False because this is the top level of the forest, if you move down to any sub-OU in the directory you should see the same permissions and Inherited should be True.  

![image](https://github.com/user-attachments/assets/7818fb4c-2c4a-4bec-b40d-e7e8cbb07638)

**Note**: The Extended Rights for Replicating Directory Changes will not be present here, since those are only set at the top level and don't need to be applied to sub-OUs.
