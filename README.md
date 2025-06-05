# AgentACLs
Scripts to support the ACLing of AD service accounts for a Source AD management agent.

Simply run the PowerShell script with the -OU command and provide an OU that you want to check.

![image](https://github.com/user-attachments/assets/fc92d969-4f0d-4d71-b777-66c3e0ecc268)


The script will return a list of all users \ groups delegated rights to the OU, along with the attribute and scope (AppliedTo) of the permission (ie. User, Group, Contact etc…).

If there are a large number of delegated permissions, you can also provide the -Identity switch to define a user / group using the UserPrincipalName, ObjectSID, ObjectGUID or SamAccountName attribute of that object and the report will only display those object’s rights.

![image](https://github.com/user-attachments/assets/10feb252-fc64-4fb2-8bde-851f0c35491c)

The output from the command should display the service account name provided, along with a list of all permissions delegated at the OU specified with the **-OU** switch

![image](https://github.com/user-attachments/assets/9962e689-f630-4685-b7ef-9a61f2a10cdb)

**NOTE**: It will show Inherited False because this is the top level of the forest, if you move down to any sub-OU in the directory you should see the same permissions and Inherited should be True.
