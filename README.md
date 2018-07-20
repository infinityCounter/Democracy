# Democracy brought to Solidity!

**Note**: Before going any further please be aware this code is still in **Alpha** and has not been throughly tested and is subject to change.

Democracy is a contract intended to be included in other solidity contracts or deployed as a standalone contract to implement a democratic governance system in one or a group of smart contracts.

Recommendation
---
This contract is still in **Alpha** and is not recommended for use in production codebases.

This contract is best used in situations where a group of 3 or more persons are/may be required to govern a single or a group of contracts. If all that is required is a single control entity then it may be best to use a pre-existing governance contract such as [OpenZeppelin Ownable](https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/ownership/Ownable.sol)

Installation
---
At this time this contract isn't available through any dependency management repositories like ethpm. You'll just have to download the code from github.

Usage
---
Democracy can be used similarly to existing solidity governance contracts like so.

    import 'Democracy.sol';
    
    contract MyContract is Democracy {
      ...
    }


How does it work?
---
The governance system is composed of a council of ***representatives***. There is a single special representative, the ***Governor***, which is elected by the representatives. In initially deploying the contract, the address that deployed the contract becomes both the first representative and the Governor. 

Each representative has the power to create a motion which is simply a request to take some form of action, such as to add or dismiss a representative, elect a new governor, or change the requirements for a motion to be enacted. Additionally each representative has the right to vote on an open motion.
There are 3 conditions under which a motion may pass:

 - A majority vote of representatives
 - A vote by fixed minimum number of representatives
 - A vote by a fixed minimum percentage of the representative body

By default all motions require a majority vote by representatives.  A motion is required to meet the minimum requirements before the deadline assigned to the motion to be approved.

After a motion has been approved it may be enacted by any representative. However the motion may still be cancelled before it is enacted, by the creator of the motion. Once a motion is enacted it cannot be undone and another motion must be created to undo the ramifications of that motion.