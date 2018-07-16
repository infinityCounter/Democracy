/*
 * @title Democracy governance contract for Solidity contracts.
 * @author Emile Keith <me@emile.bz>
 *
 * @dev This contract implements democractic governance in contract to the traditional
 *      dictatorial/monarchical solution commonly used such as open-zeppelin Ownable.
 *      While the contract achieves a democractic consensus it is still possible to configure
 *      the contract to act in a dictatorial manor, however due to it's size it would may be
 *      preferrential to use a simple Ownable contract if that is all that is desired.
 *
 *      The contract creates a governing council of represenatives where a single represenative,
 *      the Governor, serves as the head of the council. Members of the councils can propose motions
 *      to the council for other memebers to vote on.
 *

 *      A motion can be to elect a new represenative or Governor, dismiss a represenative,
 *      or to change the approval requirements for a motion type.
 *      Motions that have reached the minimum threshold of approval for their type
 *      are made available to be enacted. For each type of motion the minimum threshold 
 *      may be set to a majority of representatives, a fixed number of reprsentatives, 
 *      or a fixed minimum percetage of representatives. 

 *      The Governor also holds the ability to veto non-enacted motions which are vetoable 
 *      (as deemed by its approval requirements). An approved motion may still be cancelled 
 *      by the representative who proposed the motion before it is enacted, however 
 *      any represenative may enact an approved motion.
 
 
 *      An enacted motion to dismiss the Governor as a reprsenative will leave the Governor position vacant. Similarly
 *      An enacted motion to elect a Governor that is not yet a represenative will make him so.
 *
 *      Events will be fired when a motion is approved, enacted, cancelled, vetoed,
 *      or the Governor is changed, representative is elected or dismissed
 */

pragma solidity ^0.4.4;

contract Democracy {

    enum MotionType { ELECT_REPRESENTATIVE, DISMISS_REPRESENTATIVE, ELECT_GOVERNOR, REVISE_MOTION_APPROVAL_REQ }

    enum MotionApprovalType { APPROVAL_MAJORITY, APPROVAL_FIXED_MIN_NUM, APPROVAL_FIXED_MIN_PERC }

    // Address of new governor and motionId
    event GovernorChanged(address, uint);
    event RepresentativeElected(address, uint);
    event RepresentativeDismissed(address, uint);
    // Motion type, motion
    event MotionApprovalRequirementsRevised(uint, uint);

    event VotePlaced(address, uint);

    event MotionApproved(uint);
    event MotionEnacted(uint);
    event MotionCancelled(uint);
    event MotionVetoed(uint);

    struct MotionApprovalRequirement {
        MotionApprovalType      approvalType;
        uint                    minApproval;
        bool                    vetoable; // can be vetoed by the governor
    }

    struct MotionTarget {
        address                         representativeTarget;
        MotionApprovalRequirement       motionApprovalRevision;
    }

    struct Motion {
        MotionType   motionType;
        MotionTarget target;
        string       description;
        address      creator;
        uint         approvalDeadline;
        bool         approved;
        bool         enacted;
        bool         vetoed;
        bool         cancelled;
    }

    struct Vote {
        uint    motionId;
        address voter;
    }

    address                     public governor;
    mapping(address => uint)    public representativeIndexes;
    address[]                   public representatives;
    uint                        public numRepresentatives;
    Motion[]                    public motions;
    Vote[]                      public votes;
    mapping(uint => uint[])     public votesByMotionId;
    mapping(address => uint[])  public votesByVoterId;
    // To access the approval requirements for a motion type
    // the motion type must be cast to a uint 
    // e.g. approvalRequirementsByMotionType[uint(motion.motionType)]
    mapping(uint => MotionApprovalRequirement) public approvalRequirmentsByMotionType;


    modifier onlyGovernor(address _claimant) {
        require(_claimant == governor, "This address is not authorized to perform this action");
        _;
    }

    modifier onlyRepresentative(address _claimant) {
        address repFromLookup = representatives[representativeIndexes[_claimant]];
        require(_claimant == governor || _claimant == repFromLookup, "This address is not authorized to perform this action");
        _;
    }

    modifier motionOpen(uint _motionId) {
        require(_motionId < motions.length, "Motion does not exist");
        Motion memory motion = motions[_motionId];
        require(motion.approvalDeadline > now && !motion.vetoed && !motion.cancelled, "This motion is currently not open");
        _;
    }

    constructor() {
        governor = msg.sender;
        representativeIndexes[msg.sender] = representatives.push(msg.sender) - 1;
        numRepresentatives = 1;
        MotionApprovalRequirement memory req = MotionApprovalRequirement({
            approvalType: MotionApprovalType.APPROVAL_MAJORITY,
            minApproval: 1,
            vetoable: false
        });
        // By default all motion types are not vetoable and require majority approval
        approvalRequirmentsByMotionType[0] = req;
        approvalRequirmentsByMotionType[1] = req;
        approvalRequirmentsByMotionType[2] = req;
        approvalRequirmentsByMotionType[3] = req;
    }

    function isGovernor(address _claimant) public returns (bool) {
        return _claimant == governor;
    }

    function getRepresentativeCount() public returns (uint) {
        return numRepresentatives;
    }

    function isRepresentative(address _claimant) public returns (bool) {
        return representatives[representativeIndexes[_claimant]] ==_claimant;
    }

    function _createBasicRepresentativeMotion(MotionType motionType, string _desc, address _proposedRep, uint _deadline) internal onlyRepresentative(msg.sender) returns (uint) {
        require(_deadline > now, "Motion deadline must be later than current datetime");
        Motion memory motion;
        motion.motionType = motionType;
        motion.target.representativeTarget = _proposedRep;
        motion.description = _desc;
        motion.creator = msg.sender;
        motion.approvalDeadline = _deadline;
        return motions.push(motion);
    }

    function createElectRepresentativeMotion(string _desc, address _proposedRep, uint _deadline) public returns (uint) {
        address repFromLookup = representatives[representativeIndexes[_proposedRep]];
        require (repFromLookup != _proposedRep, "That address is already a representative");
        return _createBasicRepresentativeMotion(MotionType.ELECT_REPRESENTATIVE, _desc, _proposedRep, _deadline);
    }

    function createDismissRepresentativeMotion(string _desc, address _proposedRep, uint _deadline) public returns (uint) {
        address repFromLookup = representatives[representativeIndexes[_proposedRep]];
        require (repFromLookup == _proposedRep, "That address is not a reprsenatative");
        return _createBasicRepresentativeMotion(MotionType.DISMISS_REPRESENTATIVE, _desc, _proposedRep, _deadline);
    }

    function createElectGovernorMotion(string _desc, address _proposedGov, uint _deadline) public returns (uint) {
        require(_proposedGov != governor, "That address is already the governor");
        return _createBasicRepresentativeMotion(MotionType.ELECT_GOVERNOR, _desc, _proposedGov, _deadline);
    }

    function createReviseLegislationMotion(string _desc, uint8 _proposedApprovalType, uint _proposedApprovalVal, bool _proposedVetoable, uint _deadline) public onlyRepresentative(msg.sender) returns (uint) {
        require(_deadline >now, "Motion deadline must be later than current datetime");
        Motion memory motion;
        motion.motionType = MotionType.REVISE_MOTION_APPROVAL_REQ;
        motion.target.motionApprovalRevision.approvalType = MotionApprovalType(_proposedApprovalType);
        motion.target.motionApprovalRevision.minApproval = _proposedApprovalVal;
        motion.target.motionApprovalRevision.vetoable = _proposedVetoable;
        motion.description = _desc;
        motion.creator = msg.sender;
        motion.approvalDeadline = _deadline;
        return motions.push(motion);
    }

    function voteForMotion(uint _motionId) public onlyRepresentative(msg.sender) motionOpen(_motionId) returns (uint) {
        uint voteId = votes.push(Vote({
            motionId: _motionId,
            voter: msg.sender
        }));
        
        votesByMotionId[_motionId].push(voteId);
        votesByVoterId[msg.sender].push(voteId);

        Motion storage motion = motions[_motionId];
        MotionApprovalRequirement memory req = approvalRequirmentsByMotionType[uint(motion.motionType)];
        
        if (req.approvalType == MotionApprovalType.APPROVAL_MAJORITY &&
            votesByMotionId[_motionId].length >= numRepresentatives/2) {
            motion.approved = true;
        } else if (req.approvalType == MotionApprovalType.APPROVAL_FIXED_MIN_NUM &&
            votesByMotionId[_motionId].length >= req.minApproval) {
            motion.approved = true;
        } else if (req.approvalType == MotionApprovalType.APPROVAL_FIXED_MIN_NUM &&
            votesByMotionId[_motionId].length >= (numRepresentatives / 100 * req.minApproval)) {
            motion.approved = true;
        }

        emit VotePlaced(msg.sender, _motionId);
        if (motion.approved) {
            emit MotionApproved(_motionId);
        }
        return voteId;
    }

    function cancelMotion (uint _motionId) public onlyRepresentative(msg.sender) motionOpen(_motionId) returns (uint) {
        Motion storage motion = motions[_motionId];
        require(msg.sender == motion.creator, "This address is not authorized to cancel this motion");
        motion.cancelled = true;
        emit MotionCancelled(_motionId);
    }

    function vetoMotion (uint _motionId) public onlyGovernor(msg.sender) motionOpen(_motionId) returns (uint) {
        Motion storage motion = motions[_motionId];
        MotionApprovalRequirement memory req = approvalRequirmentsByMotionType[uint(motion.motionType)];
        require(req.vetoable == true, "This motion type is not vetoable");
        motion.vetoed = true;
        emit MotionVetoed(_motionId);
    }

    function _enactMotion(uint _motionId) internal onlyRepresentative(msg.sender) motionOpen(_motionId) {
        Motion storage motion = motions[_motionId];
        require(motion.approved, "This motion has not beed approved");
        require(!motion.enacted, "This motion has already been enacted");
        motion.enacted = true;
        address rep = motion.target.representativeTarget;

        if (motion.motionType == MotionType.ELECT_REPRESENTATIVE) {
            representativeIndexes[rep] = representatives.push(rep) - 1;
            numRepresentatives++;
            emit RepresentativeElected(rep, _motionId);
        } else if (motion.motionType == MotionType.DISMISS_REPRESENTATIVE) {
            if (rep == governor) {
                governor = address(0); // Fire the governor from the representatives
                emit GovernorChanged(governor, _motionId);
            }
            uint indexToBeDeleted = representativeIndexes[rep];
            uint finalIndex = representatives.length - 1;
            if (indexToBeDeleted == finalIndex) {
                representatives[indexToBeDeleted] = address(0);
                representativeIndexes[rep] = 0;
            } else {
                // The reprsentative list is unordered so to delete an index
                // just move the tail address in the array to the index to be
                // deleted, change the uint in the index lookup map for the tail
                // and set the uint in the index lookup for the index to be deleted to 0
                address finalRepresentative = representatives[finalIndex];
                representatives[indexToBeDeleted] = finalRepresentative;
                representatives[finalIndex] = address(0);
                representativeIndexes[rep] = 0;
                representativeIndexes[finalRepresentative] = indexToBeDeleted;
            }
            numRepresentatives--;
            emit RepresentativeDismissed(rep, _motionId);
        } else if (motion.motionType == MotionType.ELECT_GOVERNOR) {
            if  (representatives[representativeIndexes[rep]] != rep) {
                representativeIndexes[rep] = representatives.push(rep) - 1;
                numRepresentatives++;
            }
            governor = rep;
            emit GovernorChanged(governor, _motionId);
        } else {
            uint castType = uint(motion.motionType);
            approvalRequirmentsByMotionType[castType] = motion.target.motionApprovalRevision;
            emit MotionApprovalRequirementsRevised(castType, _motionId);
        }
        emit MotionEnacted(_motionId);
    }
}