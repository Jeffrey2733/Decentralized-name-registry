### README.md

# Name Registry Smart Contract  

**Description**  
The **Name Registry Smart Contract** allows users to claim unique names and associate them with their principal addresses. It provides a decentralized mechanism to ensure each name is owned by only one user at a time.  

## Features  
- **Claim a Name:**  
  Securely claim ownership of a unique name. Once claimed, no other user can take it.  

- **Retrieve Ownership:**  
  Check who owns a specific name using a simple read-only query.  

- **Immutable Ownership:**  
  Names are tied to the principal address of the user who claimed them, ensuring trust and transparency.  

---

## Functions  

### Public Functions  

#### `claim-name`  
**Parameters:**  
- `name (string-ascii 50)`: The unique name to be claimed.  

**Behavior:**  
- If the name is already claimed, returns an error (`u100`).  
- Otherwise, associates the name with the caller's principal.  

**Returns:**  
- `ok true`: If the claim is successful.  
- `err u100`: If the name is already claimed.  

---

### Read-Only Functions  

#### `get-owner`  
**Parameters:**  
- `name (string-ascii 50)`: The name to query ownership for.  

**Behavior:**  
- Retrieves the principal address of the owner of the given name.  

**Returns:**  
- `some principal`: If the name is claimed.  
- `none`: If the name is unclaimed.  

---

## Unit Tests  

Unit tests for this smart contract were implemented using a mock framework to simulate its behavior. Below is a summary of the tests:  

### Test Cases  

#### Claiming Names  
1. **Unique Name Claim:**  
   - A user can claim a name that hasn’t been taken.  

2. **Duplicate Name Claim:**  
   - A second user attempting to claim an already-claimed name receives an error (`u100`).  

#### Retrieving Ownership  
1. **Retrieve Existing Owner:**  
   - The correct principal address is returned for a claimed name.  

2. **Retrieve Unclaimed Name:**  
   - A query for an unclaimed name returns `null`.  

---

## Deployment  

1. Deploy the smart contract to your desired blockchain network.  
2. Test the contract by executing the provided unit tests to ensure everything works as expected.  

---

## Example Usage  

### Claim a Name  
```clarity
(claim-name "my-unique-name")
```  

### Get the Owner of a Name  
```clarity
(get-owner "my-unique-name")
```  

---

## Contributing  
Contributions are welcome! Feel free to fork this repository and open a pull request with your improvements or suggestions.  

---

## License  
This project is open-source under the MIT License.  
