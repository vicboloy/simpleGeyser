pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/upgrades-core/contracts/Initializable.sol";
import "@openzeppelin/contracts/GSN/Context.sol";


contract AccessRule is Context, Initializable, AccessControl {

	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

	/**
	* @dev Add `rootAdmin` to the admin role as a member.
	**/ 
  	function initialize(address _rootAdmin) public initializer {
    	_setupRole(DEFAULT_ADMIN_ROLE, _rootAdmin);
   		_setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
  	}

	/**
	* @dev Restricted to members of the admin role.
	**/
  	modifier onlyAdmin() {
    	require(hasAdminRole(_msgSender()), "Restricted to admins.");
    	_;
  	}

  	/**
	* @dev @dev Restricted to members of the user role.
	**/
  	modifier onlyMinter() {
    	require(hasMinterRole(_msgSender()), "Restricted to users.");
    	_;
  	}

  	/**
  	 *	@dev Returns `true` if the account has admin role;
  	**/
  	function hasAdminRole(address _account) public virtual view returns (bool) {
  		return hasRole(DEFAULT_ADMIN_ROLE, _account);
  	}

  	/**
  	 * @dev Returns `true` if the account has minter role;
  	**/
  	function hasMinterRole(address _account) public virtual view returns (bool) {
  		return hasRole(MINTER_ROLE, _account);
  	}

	/**
     * @dev Grant admin role to the minter, caller should be the default/super admin role.
     * @param _account Address that will be given the admin role of the Minter role.
     * 
    **/
    function setAdmin(address _account) public virtual onlyAdmin {
    	grantRole(DEFAULT_ADMIN_ROLE, _account);
    }

	/**
     * @dev Grant the adress a minter role by the admin. Caller should have admin role.
     * @param _minter Address that will be given a minter role
     * 
    **/
    function setMinter(address _minter) public virtual onlyAdmin {
    	grantRole(MINTER_ROLE, _minter);
    }

    /**
     * @dev Revoke the adress a minter role by the admin. Caller should have admin role.
     * @param _minter Address that will be revoked it's minter role.
     * 
    **/
    function removeMinter(address _minter) public virtual onlyAdmin {
    	revokeRole(MINTER_ROLE, _minter);
    }

    /**
     *	@dev Remove self from admin role.	
    **/
    function renounceAdmin() public virtual {
    	renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }
}