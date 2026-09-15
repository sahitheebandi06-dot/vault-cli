## Master password
**As as** user,

**I want to** create a master password

**so that I can** protect my stored passwords.

### Acceptance Criteria
#### 1
**Given** I am a user

*And* no vault exists

**When** I start vault CLI

**Then** I am prompted to create a new master password

#### 2
**Given** I am a user

*And* no vault exists

*And* I am creating a new master password

**When** I enter a valid password 

*And* I enter a different password when prompted again

**Then** the password is rejected

*And* I am prompted to try again

#### 3
**Given** I am a user

*And* no vault exists

*And* I am creating a new master password

**When** I enter a valid password both times

**Then** a new vault is created

*And* I am taken to the menu screen

#### 4
**Given** I am a user

*And* no vault exists

*And* I am creating a new master password

**When** I enter an invalid password 

**Then** the password is rejected

*And* I am told that the password is invalid

*And* I am prompted to try again

#### 5
**Given** I am a user

*And* a vault already exists

*And* I am logging into VaultCLI

**When** I enter the correct password

**Then** I am taken to the menu screen

#### 6
**Given** I am a user

*And* a vault already exists

*And* I am logging into VaultCLI

**When** I enter an incorrect password

**Then** I am told that the password is invalid

*And* I am prompted to try again

*And* I am told the amount of attempts I have remaining

#### 7
**Given** I am a user

*And* a vault already exists

*And* I am logging into VaultCLI

*And* I only have 1 attempt left

**When** I enter an incorrect password

**Then** I am told that the password is invalid

*And* the program exits

---

## Add credentials
**As a** user,

**I want to** add credentials for an app

**so that I can** store my credentials using VaultCLI

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

**When** I choose to add a new credential

**Then** I am taken to the new credential dialog

#### 2
**Given** I am a user signed into VaultCLI

*And* I am adding a new credential

**When** I input a username

*And* I input a valid password

**Then** the credential is stored to the vault

*And* I am taken back to the menu screen

---

## Password generator
**As a** user,

**I want to** generate a random password

**so that I can** use strong passwords

### Acceptance Critiera
#### 1
**Given** I am a user signed into VaultCLI

*And* I am creating a new credential

*And* I have provided a username

**When** I choose to generate a random password

**Then** a random password is generated for this credential

*And* the credential is stored in the vault

*And* the credential is displayed for my reference

---

## Search credentials
**As a** user,

**I want to** search for my credentials

**so that I can** use them when I need them

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

**When** I choose to search my credentials

**Then** I am taken to the credential search dialog

#### 2
**Given** I am a user signed into VaultCLI

*And* I am on the credential search dialog

**When** I type in a search term that at least partially matches at least 1 credential

**Then** all credentials that match the search term are displayed

*And* I am taken back to the menu

#### 3
**Given** I am a user signed into VaultCLI

*And* I am on the credential search dialog

**When** I type in a search term that does not match any stored credentials

**Then** I am told no credentials have been found

*And* I am taken back to the menu

#### 4
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

*And* I have at least one credential stored

**When** I choose to list all credentials

**Then** all stored sites and usernames are shown

*And* no passwords are shown

*And* I am taken back to the menu

#### 5
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

*And* I have no credentials stored

**When** I choose to list all credentials

**Then** I am told no credentials are stored

*And* I am taken back to the menu

---


## Delete credentials
**As a** user,

**I want to** delete stored credentials

**so that I can** clear old and unwanted credentials from VaultCLI

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

**When** I choose to delete a credential

**Then** I am taken to the delete credential dialog

#### 2
**Given** I am a user signed into VaultCLI

*And* I am deleting a credential

*And* there is at least 1 credential stored

**When** I correctly enter the site name of a stored credential

**Then** that credential is removed from the vault

*And* I am taken back to the menu

#### 2
**Given** I am a user signed into VaultCLI

*And* I am deleting a credential

**When** I enter a site name that does not match a stored credential

**Then** I am told no credential was found for the provided site name

*And* I am taken back to the menu

---

## Password strength rating
**As a** user,

**I want to** be informed of the strength of my passwords

**so that I can** know that I've created a strong and secure password

### Acceptance Criteria
#### 
**Given** I am a user signed into VaultCLI

*And* I am adding a new credential

**When** I enter or generate a password

*And* I create the credential

**Then** I am told the strength of the saved password

---

## Category filtering
**As a** user,

**I want to** filter my credentials by category

**so that I can** quickly find relevant credentials based on their type.

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

**When** I choose to filter credentials by category

**Then** I am taken to the category filter dialog

#### 2
**Given** I am on the category filter dialog

**When** I select a category that has at least one credential

**Then** all credentials belonging to that category are displayed

*And* I am taken back to the menu

#### 3
**Given** I am on the category filter dialog

**When** I select a category with no stored credentials

**Then** I am told no credentials have been found for that category

*And* I am taken back to the menu

---

## Update existing passwords
**As a** user,

**I want to** update the password for a stored credential

**so that I can** keep my credentials secure by changing passwords when needed.

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

**When** I choose to update a credential's password

**Then** I am taken to the update password dialog

#### 2
**Given** I am on the update password dialog

*And* there is at least one credential stored

**When** I correctly enter the site name of a stored credential

*And* I provide a new valid password

**Then** the password for that credential is updated

*And* I am taken back to the menu

#### 3
**Given** I am on the update password dialog

**When** I enter a site name that does not match any stored credential

**Then** I am told no credential was found for the provided site name

*And* I am taken back to the menu

---

## Clipboard copy (don’t show password on screen)
**As a** user,

**I want to** copy my password to the clipboard without displaying it on screen

**so that I can** safely use passwords without exposing them.

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

**When** I choose to copy a password for a credential

**Then** I am taken to the copy password dialog

#### 2
**Given** I am on the copy password dialog

*And* there is at least one credential stored

**When** I correctly enter the site name of a stored credential

**Then** the password is copied to my clipboard

*And* the password is not shown on the screen

*And* I am notified that the password was copied

*And* I am taken back to the menu

#### 3
**Given** I am on the copy password dialog

**When** I enter a site name that does not match any stored credential

**Then** I am told no credential was found for the provided site name

*And* I am taken back to the menu

---

## Import from CSV
**As a** user,

**I want to** import credentials from a CSV file

**so that I can** quickly add multiple credentials at once.

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I am on the menu screen

**When** I choose to import from CSV

**Then** I am prompted to provide a CSV file path

#### 2
**Given** I provide a valid CSV file

**When** the file is successfully read

**Then** all credentials from the CSV are imported to the vault

*And* I am notified of the number of credentials imported

*And* I am taken back to the menu

#### 3
**Given** I provide an invalid or improperly formatted CSV file

**When** the file cannot be read or parsed

**Then** I am told the CSV file is invalid

*And* I am prompted to try again

*And* I am taken back to the menu

---

## Password expiry reminders
**As a** user,

**I want to** receive reminders when a password is about to expire

**so that I can** proactively update my passwords to keep them secure.

### Acceptance Criteria
#### 1
**Given** I am a user signed into VaultCLI

*And* I have a credential with an expiry date approaching

**When** I log into VaultCLI or access the menu screen

**Then** I am notified of credentials with passwords about to expire

*And* I am shown the option to update those passwords

#### 2
**Given** I have credentials with expired passwords

**When** I access the menu screen

**Then** I am notified which credentials have expired passwords

*And* I am prompted to update those passwords

#### 3
**Given** I have no credentials with expiring passwords

**When** I access the menu screen

**Then** I am not notified about password expiry