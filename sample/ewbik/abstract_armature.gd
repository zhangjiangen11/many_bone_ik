@tool
extends Object

class_name AbstractArmature

private int IKIterations = 30;
protected AbstractAxes localAxes;
protected AbstractAxes tempWorkingAxes;
protected ArrayList<AbstractBone> bones = new ArrayList<AbstractBone>();
protected HashMap<String, AbstractBone> tagBoneMap = new HashMap<String, AbstractBone>();

protected HashMap<AbstractBone, SegmentedArmature> boneSegmentMap = new HashMap<AbstractBone, SegmentedArmature>();
protected AbstractBone rootBone;
protected WorkingBone[] traversalArray;
protected WorkingBone[] returnfulArray;
protected HashMap<AbstractBone, Integer> traversalIndex;
protected HashMap<AbstractBone, Integer> returnfulIndex;
public SegmentedArmature segmentedArmature;
protected String tag;

protected double dampening = Math.toRadians(5d);
private boolean abilityBiasing = false;

public double IKSolverStability = 0d;
PerformanceStats performance = new PerformanceStats();

public int defaultStabilizingPassCount = 1;

AbstractAxes fauxParent;

/**
 * Initialize an Armature with a default root bone matching the given
 * parameters.. The rootBone's length will be 1.
 * 
 * @param inputOrigin Desired location and orientation of the rootBone.
 * @param name        A human readable name for this armature
 */
public AbstractArmature(AbstractAxes inputOrigin, String name) {

    this.localAxes = (AbstractAxes) inputOrigin;
    this.tempWorkingAxes = localAxes.getGlobalCopy();
    this.tag = name;
    createRootBone(localAxes.y_().heading(), localAxes.z_().heading(), tag + " : rootBone", 1d,
            AbstractBone.frameType.GLOBAL);
}

/**
 * Set the inputBone as this Armature's Root Bone.
 * 
 * @param inputBone
 * @return
 */
public AbstractBone createRootBone(AbstractBone inputBone) {
    this.rootBone = inputBone;
    this.segmentedArmature = new SegmentedArmature(rootBone);
    fauxParent = rootBone.localAxes().getGlobalCopy();

    return rootBone;
}

private <V extends Vec3d<?>> AbstractBone createRootBone(V tipHeading, V rollHeading, String inputTag,
        double boneHeight, AbstractBone.frameType coordinateType) {
    initializeRootBone(this, tipHeading, rollHeading, inputTag, boneHeight, coordinateType);
    this.segmentedArmature = new SegmentedArmature(rootBone);
    fauxParent = rootBone.localAxes().getGlobalCopy();

    return rootBone;
}

protected abstract void initializeRootBone(AbstractArmature armature, Vec3d<?> tipHeading, Vec3d<?> rollHeading,
        String inputTag, double boneHeight, AbstractBone.frameType coordinateType);

/**
 * The default number of iterations to run over this armature whenever
 * IKSolver() is called. The higher this value, the more likely the Armature is
 * to have converged on a solution when by the time it returns. However, it will
 * take longer to return (linear cost)
 * 
 * @param iter
 */
public void setDefaultIterations(int iter) {
    this.IKIterations = iter;
    regenerateShadowSkeleton();
}

/**
 * The default maximum number of radians a bone is allowed to rotate per solver
 * iteration. The lower this value, the more natural the pose results. However,
 * this will the number of iterations the solver requires to converge.
 * 
 * !!THIS IS AN EXPENSIVE OPERATION. This updates the entire armature's cache of
 * precomputed quadrance angles. The cache makes things faster in general, but
 * if you need to dynamically change the dampening during a call to IKSolver,
 * use the IKSolver(bone, dampening, iterations, stabilizationPasses) function,
 * which clamps rotations on the fly.
 * 
 * @param damp
 */
public void setDefaultDampening(double damp) {
    this.dampening = Math.min(Math.PI * 3d, Math.max(Math.abs(Double.MIN_VALUE), Math.abs(damp)));
    regenerateShadowSkeleton();
}

/**
 * @return the rootBone of this armature.
 */
public AbstractBone getRootBone() {
    return rootBone;
}

/**
 * (warning, this function is untested)
 * 
 * @return all bones belonging to this armature.
 */
public ArrayList<? extends AbstractBone> getBoneList() {
    this.bones.clear();
    rootBone.addDescendantsToArmature();
    return bones;
}

/**
 * The armature maintains an internal hashmap of bone name's and their
 * corresponding bone objects. This method should be called by any bone object
 * if ever its name is changed.
 * 
 * @param bone
 * @param previousTag
 * @param newTag
 */
protected void updateBoneTag(AbstractBone bone, String previousTag, String newTag) {
    tagBoneMap.remove(previousTag);
    tagBoneMap.put(newTag, bone);
}

/**
 * this method should be called by any newly created bone object if the armature
 * is to know it exists.
 * 
 * @param bone
 */
protected void addToBoneList(AbstractBone abstractBone) {
    if (!bones.contains(abstractBone)) {
        bones.add(abstractBone);
        tagBoneMap.put(abstractBone.getTag(), abstractBone);
        this.regenerateShadowSkeleton();
    }
}

/**
 * this method should be called by any newly deleted bone object if the armature
 * is to know it no longer exists
 */
protected void removeFromBoneList(AbstractBone abstractBone) {
    if (bones.contains(abstractBone)) {
        bones.remove(abstractBone);
        tagBoneMap.remove(abstractBone);
        this.regenerateShadowSkeleton();
    }
}

/**
 * 
 * @param tag the tag of the bone object you wish to retrieve
 * @return the bone object corresponding to this tag
 */

public AbstractBone getBoneTagged(String tag) {
    return tagBoneMap.get(tag);
}

/**
 * 
 * @return the user specified tag String for this armature.
 */
public String getTag() {
    return this.tag;
}

/**
 * @param A user specified tag string for this armature.
 */
public void setTag(String newTag) {
    this.tag = newTag;
}

/*
 * @param inverseWeighted if true, will apply an additional rotation penalty on
 * the peripheral bones near a target so as to result in more natural poses with
 * less need for dampening.
 */
/*
 * public void setInverseWeighted(boolean inverseWeighted) {
 * this.inverseWeighted = inverseWeighted; }
 * 
 * public boolean isInverseWeighted() { return this.inverseWeighted; }
 */

private boolean dirtySkelState = false;
private boolean dirtyRate = false;
SkeletonState skelState;

/**
 * a list of the bones used by the solver, in the same order they appear in the skelState after validation.
 * This is to very quickly update the scene with the solver's results, without incurring hashmap lookup penalty. 
 * **/
protected AbstractBone[] skelStateBoneList = new AbstractBone[0];

ShadowSkeleton shadowSkel;
private void _regenerateShadowSkeleton() {
    skelState = new SkeletonState();
    for(AbstractBone b: bones) {
        registerBoneWithShadowSkeleton(b);
    }
    skelState.validate();
    shadowSkel = new ShadowSkeleton(skelState, this);
    skelStateBoneList = new AbstractBone[skelState.getBoneCount()];
    for(int i=0; i<bones.size(); i++) {
        BoneState bonestate = skelState.getBoneStateById(bones.get(i).getIdentityHash());
        if(bonestate != null)
            skelStateBoneList[bonestate.getIndex()] = bones.get(i);
    }
    dirtySkelState = false;
}


/**
 * This method should be called whenever a structural change has been made to the armature prior to calling the solver.
 * A structural change is basically any change other than a rotation/translation/scale of a bone or a target. 
 * Structural changes include things like, 
 *		1. reparenting / adding / removing bones. 
 * 	2. marking a bone as an effector (aka "pinning / unpinning a bone"
 * 	3. adding / removing a constraint on a bone.
 * 	4. modifying a pin's fallOff to non-zero if it was zero, or zero if it was non-zero
 * 
 * You should NOT call this function if you have only modified a translation/rotation/scale of some transform on the armature
 * 
 * For skeletal modifications that are likely to effect the solver behavior but do not fall 
 * under any of the above (generally things like changing bone stiffness, depth falloff, targetweight, etc) to intermediary values, 
 * you should (but don't have to) call updateShadowSkelRateInfo() for maximum efficiency.
 */
public void regenerateShadowSkeleton() {
    this.regenerateShadowSkeleton(false);
}
 /**
 * @param force by default, callign this function sets a flag notifying the solver that it needs to regenerate the shadow skeleton before
 * attempting a solve. If you set this to "true", the shadow skeleton will be regenerated immediately. 
 * (useful if you do solves in a separate thread from structure updates)
 */
public void regenerateShadowSkeleton(boolean force) {
    dirtySkelState = true;
    if(force) 
        this._regenerateShadowSkeleton();
    dirtyRate = true;
    /*segmentedArmature.updateSegmentedArmature();
    boneSegmentMap.clear();
    recursivelyUpdateBoneSegmentMapFrom(segmentedArmature);
    SegmentedArmature.recursivelyCreateHeadingArraysFor(segmentedArmature);
    WorkingBone[][] built = buildTraversalArrayFromGroups(segmentedArmature);
    traversalArray = built[0];
    returnfulArray = built[1];
    traversalIndex = new HashMap<AbstractBone, Integer>();
    returnfulIndex = new HashMap<AbstractBone, Integer>();
    for (int i = 0; i < traversalArray.length; i++) {
        traversalIndex.put(traversalArray[i].forBone, i);
    }
    for (int i = 0; i < returnfulArray.length; i++) {
        returnfulIndex.put(returnfulArray[i].forBone, i);
    }*/
}

public void updateShadowSkelRateInfo() {
    dirtyRate = true;
}

private void _updateShadowSkelRateInfo() {
    BoneState[] bonestates = skelState.getBonesArray();
    for(int i=0; i<skelStateBoneList.length; i++) {
        AbstractBone b = skelStateBoneList[i];
        BoneState bs = bonestates[i];
        bs.setStiffness(b.getStiffness());
    }
}

private void registerBoneWithShadowSkeleton(AbstractBone bone) { 
    String parBoneId = (bone.getParent() == null) ? null : bone.getParent().getIdentityHash(); 
    Constraint constraint = bone.getConstraint();
    String constraintId = (constraint == null) ? null : constraint.getIdentityHash(); 
    AbstractIKPin target = bone.getIKPin();
    String targetId = (target == null || target.getPinWeight() == 0 || target.isEnabled() == false) ? null : target.getIdentityHash();
    skelState.addBone(
            bone.getIdentityHash(), 
            bone.localAxes().getIdentityHash(), 
            parBoneId, 
            constraintId, 
            bone.getStiffness(),
            targetId);
    registerAxesWithShadowSkeleton(bone.localAxes(), bone.getParent() == null);
    if(targetId != null) registerTargetWithShadowSkeleton(target);
    if(constraintId != null) registerConstraintWithShadowSkeleton(constraint);
    
}
private void registerTargetWithShadowSkeleton(AbstractIKPin ikPin) {
    skelState.addTarget(ikPin.getIdentityHash(), 
            ikPin.getAxes().getIdentityHash(), 
            ikPin.forBone().getIdentityHash(),
            new double[] {ikPin.getXPriority(), ikPin.getYPriority(), ikPin.getZPriority()}, 
            ikPin.getDepthFalloff(),
            ikPin.getPinWeight());
    registerAxesWithShadowSkeleton(ikPin.getAxes(), true);
}
private void registerConstraintWithShadowSkeleton(Constraint constraint) {
    AbstractAxes twistAxes = constraint.twistOrientationAxes() == null ? null : constraint.twistOrientationAxes();
    skelState.addConstraint(
            constraint.getIdentityHash(),
            constraint.attachedTo().getIdentityHash(),
            constraint.swingOrientationAxes().getIdentityHash(),
            twistAxes == null ? null : twistAxes.getIdentityHash(),
            constraint);
    registerAxesWithShadowSkeleton(constraint.swingOrientationAxes(), false);
    if(twistAxes != null)
        registerAxesWithShadowSkeleton(twistAxes, false);
    
}
/**
 * @param axes
 * @param rebase if true, this function will not provide a parent_id for these axes.
 * This is mostly usefu l for ensuring that targetAxes are always implicitly defined in skeleton space when calling the solver.
 * You should always set this to true when giving the axes of an IKPin, as well as when giving the axes of the root bone. 
 * see the skelState.addTransform documentation for more info. 
 */
private void registerAxesWithShadowSkeleton(AbstractAxes axes, boolean unparent) {
    String parent_id  = unparent || axes.getParentAxes() == null ? null : axes.getParentAxes().getIdentityHash();
    AbstractBasis basis = getSkelStateRelativeBasis(axes, unparent);
    Vec3d<?> translate = basis.translate;
    Rot rotation =basis.rotation;
    skelState.addTransform(
            axes.getIdentityHash(), 
            new double[]{translate.getX(), translate.getY(), translate.getZ()}, 
            rotation.toArray(), 
            new double[]{1.0,1.0,1.0}, 
            parent_id, axes);
}

/**
 *
 * @param axes
 * @param unparent if true, will return a COPY of the basis in Armature space, otherwise, will return a reference to axes.localMBasis
 * @return
 */
private AbstractBasis getSkelStateRelativeBasis(AbstractAxes axes, boolean unparent) {
    AbstractBasis basis = axes.getLocalMBasis(); 
    if(unparent) {
        basis = basis.copy();
        this.localAxes().getGlobalMBasis().setToLocalOf(axes.getGlobalMBasis(), basis);
    }
    return basis;
}

private void updateskelStateTransforms() {
    BoneState[] bonestates = skelState.getBonesArray();
    for(int i=0; i<skelStateBoneList.length; i++) {
        AbstractBone b = skelStateBoneList[i];
        BoneState bs = bonestates[i];
        updateSkelStateBone(b, bs);
    }
}

private void updateSkelStateBone(AbstractBone b, BoneState bs) {
    updateSkelStateAxes(b.localAxes(), bs.getTransform(), b.getParent() == null);
    if(b.getConstraint() != null) {
        updateSkelStateConstraint(b.getConstraint(), bs.getConstraint());
    }
    TargetState ts = bs.getTarget(); 
    if(ts != null) {
        updateSkelStateTarget(b.getIKPin(), ts);
    }
}

private void updateSkelStateConstraint(Constraint c, ConstraintState cs) {
    AbstractAxes swing = c.swingOrientationAxes();
        updateSkelStateAxes(swing, cs.getSwingTransform(), false);
    AbstractAxes twist = c.twistOrientationAxes();
    if(twist != null)
        updateSkelStateAxes(twist, cs.getTwistTransform(), false);
}	

private void updateSkelStateTarget(AbstractIKPin p, TargetState ts) {
    updateSkelStateAxes(p.getAxes(), ts.getTransform(), true);
}

private void updateSkelStateAxes(AbstractAxes a, TransformState ts, boolean unparent) {
    AbstractBasis basis = getSkelStateRelativeBasis(a, unparent);
    ts.rotation= basis.rotation.toArray(); 
    ts.translation = basis.translate.get();
    if(!a.forceOrthoNormality) {
        ts.scale[0] = basis.getXHeading().mag() * ( basis.isAxisFlipped(AbstractAxes.X) ? -1d : 1d);
        ts.scale[1] = basis.getYHeading().mag() * ( basis.isAxisFlipped(AbstractAxes.Y) ? -1d : 1d); 
        ts.scale[2] = basis.getZHeading().mag() * ( basis.isAxisFlipped(AbstractAxes.Z) ? -1d : 1d);
    } else {
        ts.scale[0] = basis.isAxisFlipped(AbstractAxes.X) ? -1d : 1d;
        ts.scale[1] = basis.isAxisFlipped(AbstractAxes.Y) ? -1d : 1d; 
        ts.scale[2] = basis.isAxisFlipped(AbstractAxes.Z) ? -1d : 1d;
    }
}

private void recursivelyUpdateBoneSegmentMapFrom(SegmentedArmature startFrom) {
    for (AbstractBone b : startFrom.segmentBoneList) {
        boneSegmentMap.put(b, startFrom);
    }
    for (SegmentedArmature c : startFrom.childSegments) {
        recursivelyUpdateBoneSegmentMapFrom(c);
    }
}

/**
 * If you have created some sort of save / load system for your armatures which
 * might make it difficult to notify the armature when a pin has been enabled on
 * a bone, you can call this function after all bones and pins have been
 * instantiated and associated with one another to index all of the pins on the
 * armature.
 */
public void refreshArmaturePins() {
    AbstractBone rootBone = this.getRootBone();
    ArrayList<AbstractBone> pinnedBones = new ArrayList<>();
    rootBone.addSelfIfPinned(pinnedBones);

    for (AbstractBone b : pinnedBones) {
        b.notifyAncestorsOfPin(false);
        regenerateShadowSkeleton();
    }
}

/**
 * automatically solves the IK system of this armature from the given bone using
 * the armature's default IK parameters.
 * 
 * You can specify these using the setDefaultIterations() setDefaultIKType() and
 * setDefaultDampening() methods. The library comes with some defaults already
 * set, so you can more or less use this method out of the box if you're just
 * testing things out.
 * 
 * @param bone
 */
public void IKSolver(AbstractBone bone) {
    IKSolver(bone, -1, -1, -1);
}

/**
 * automatically solves the IK system of this armature from the given bone using
 * the given parameters.
 * 
 * @param bone
 * @param dampening         dampening angle in radians. Set this to -1 if you
 *                          want to use the armature's default.
 * @param iterations        number of iterations to run. Set this to -1 if you
 *                          want to use the armature's default.
 * @param stabilizingPasses number of stabilization passes to run. Set this to
 *                          -1 if you want to use the armature's default.
 */
public void IKSolver(AbstractBone bone, double dampening, int iterations, int stabilizingPasses) {
    if(dirtySkelState) 
        _regenerateShadowSkeleton();
    if(dirtyRate) {
        _updateShadowSkelRateInfo();
        shadowSkel.updateRates();
        dirtyRate = false;
    }
    //if(traversalArray != null && traversalArray.length > 0) {
    performance.startPerformanceMonitor();
    this.updateskelStateTransforms();
    shadowSkel.solve(dampening, iterations, stabilizingPasses, (bonestate) -> alignBoneToSolverResult(bonestate));
    //alignBonesListToSolverResults();
    //flatTraveseSolver(bone, dampening, iterations, stabilizingPasses);// (bone, dampening, iterations);
    performance.solveFinished(iterations == -1 ? this.IKIterations : iterations);
    //}
}

/**
 * read back the solver results from the SkeletonState object. 
 * The solver only ever modifies the transforms of the bones themselves, and only 
 * ever in local coordinates, so we only need to read back the bones in local space and mark their transforms dirty.
 */
private void alignBonesListToSolverResults() {
    BoneState[] bonestates = skelState.getBonesArray();
    for(int i=0; i<bonestates.length; i++) {
        alignBoneToSolverResult(bonestates[i]);
    }
}

private void alignBoneToSolverResult(BoneState bs) {
    int bsi = bs.getIndex();
    AbstractBone currBone = skelStateBoneList[bsi];
    AbstractAxes currBoneAx = currBone.localAxes();
    TransformState ts = bs.getTransform();
    currBoneAx.getLocalMBasis().set(ts.translation, ts.rotation, ts.scale);
    currBoneAx._exclusiveMarkDirty();
    currBone.IKUpdateNotification();
}

/**
 * The solver tends to be quite stable whenever a pose is reachable (or
 * unreachable but without excessive contortion). However, in cases of extreme
 * unreachability (due to excessive contortion on orientation constraints), the
 * solution might fail to stabilize, resulting in an undulating motion.
 * 
 * Setting this parameter to "1" will prevent such undulations, with a
 * negligible cost to performance. Setting this parameter to a value higher than
 * 1 will offer minor benefits in pose quality in situations that would
 * otherwise be prone to instability, however, it will do so at a significant
 * performance cost.
 * 
 * You're encourage to experiment with this parameter as per your use case, but
 * you may find the following guiding principles helpful:
 * <ul>
 * <li>If your armature doesn't have any constraints, then leave this parameter
 * set to 0.</li>
 * <li>If your armature doesn't make use of orientation aware pins (x,y,and,z
 * direction pin priorities are set to 0) the leave this parameter set to 0.
 * </li>
 * <li>If your armature makes use of orientation aware pins and orientation
 * constraints, then set this parameter to 1</li>
 * <li>If your armature makes use of orientation aware pins and orientation
 * constraints, but speed is of the highest possible priority, then set this
 * parameter to 0</li>
 * </ul>
 * 
 * @param passCount
 */
public void setDefaultStabilizingPassCount(int passCount) {
    defaultStabilizingPassCount = passCount;
}

/**
 * 
 * @return a reference to the Axes serving as this Armature's coordinate system.
 */
public AbstractAxes localAxes() {
    return this.localAxes;
}

private void iterativelyNotifyBonesOfCompletedIKSolution(int startFrom, int endOn) { 
    for(int i=startFrom; i>=endOn; i--) {
        traversalArray[i].forBone.IKUpdateNotification();
    }
}
private void recursivelyNotifyBonesOfCompletedIKSolution(SegmentedArmature startFrom) {
    for (AbstractBone b : startFrom.segmentBoneList) {
        b.IKUpdateNotification();
    }
    for (SegmentedArmature s : startFrom.childSegments) {
        recursivelyNotifyBonesOfCompletedIKSolution(s);
    }
}

/**
 * @param startFrom
 * @param dampening
 * @param iterations
 */

public void flatTraveseSolver(AbstractBone startFrom, double dampening, int iterations, int stabilizationPasses) {
    int endOnIndex = traversalArray.length - 1;
    //int returnfullEndOnIndex = returnfulArray.length > 0 ? returnfulIndex.get(startFrom);  
    int tipIndex = 0;
    SegmentedArmature forSegment = segmentedArmature;
    iterations = iterations == -1 ? IKIterations : iterations;
    double totalIterations = iterations;
    stabilizationPasses = stabilizationPasses == -1 ? this.defaultStabilizingPassCount : stabilizationPasses;
    if (startFrom != null) {
        forSegment = boneSegmentMap.get(startFrom);
        if(forSegment != null) {
            AbstractBone endOnBone = forSegment.segmentRoot;
            endOnIndex = traversalIndex.get(endOnBone);
        }
    }

    iterativelyAlignSimAxesToBones(traversalArray, endOnIndex);

    for (int i = 0; i < iterations; i++) {
        for (int j = 0; j <= endOnIndex; j++) {
            traversalArray[j].fastUpdateOptimalRotationToPinnedDescendants(dampening,
                    j == endOnIndex && endOnIndex == traversalArray.length - 1);
        }
        /*if(i < totalIterations - 1) {
            for (int j = 0; j <= endOnIndex; j++) {
                traversalArray[j].pullBackTowardAllowableRegion(i, iterations);
            }
        }*/
    }

    iterativelyAlignBonesToSimAxesFrom(traversalArray, endOnIndex);
    iterativelyNotifyBonesOfCompletedIKSolution(tipIndex, endOnIndex);
}


/**returns a two element array of WorkingBone arrays in the order which they should be traversed in
 * the 0th element is for trying to reach targets, the 1st element is for trying to reach comfort.
 */
private WorkingBone[][] buildTraversalArrayFromGroups(SegmentedArmature startFrom) {
    ArrayList<WorkingBone> boneList = new ArrayList<WorkingBone>();
    ArrayList<WorkingBone> returnfulList = new ArrayList<WorkingBone>();
    buildTraversalArrayFromSegments(startFrom, boneList, returnfulList);
    WorkingBone[] boneListResult = new WorkingBone[boneList.size()];
    WorkingBone[] returnfulResult = new WorkingBone[returnfulList.size()];
    WorkingBone[][] result = {boneList.toArray(boneListResult), returnfulList.toArray(returnfulResult)};
    return result;
}

private void buildTraversalArrayFromSegments(SegmentedArmature startFrom, ArrayList<WorkingBone> boneList, ArrayList<WorkingBone> returnfulList) {
    for (SegmentedArmature a : startFrom.pinnedDescendants) {
        for (SegmentedArmature c : a.childSegments) {
            buildTraversalArrayFromSegments(c, boneList, returnfulList);
        }
    }
    buildTraversalArrayFromChains(startFrom, boneList, returnfulList);
}

private void buildTraversalArrayFromChains(SegmentedArmature chain, ArrayList<WorkingBone> boneList, ArrayList<WorkingBone> returnfulList) {
    if ((chain.childSegments == null || chain.childSegments.size() == 0) && !chain.isTipPinned()) {
        return;
    } else if (!chain.isTipPinned()) {
        for (SegmentedArmature c : chain.childSegments) {
            buildTraversalArrayFromChains(c, boneList, returnfulList);
        }
    }
    if(chain.isTipPinned() || chain.pinnedDescendants.size() > 0)
        pushSegmentBonesToTraversalArray(chain, boneList, returnfulList);
}

private void pushSegmentBonesToTraversalArray(SegmentedArmature chain, ArrayList<WorkingBone> boneList, ArrayList<WorkingBone> returnfulList) {
    AbstractBone startFrom = debug && lastDebugBone != null ? lastDebugBone : chain.segmentTip;
    AbstractBone stopAfter = chain.segmentRoot;

    AbstractBone currentBone = startFrom;
    while (currentBone != null) {
        boneList.add(chain.simulatedBones.get(currentBone));
        if(currentBone.getConstraint() != null)
            if(currentBone.getConstraint().getPainfulness() > 0) {
                returnfulList.add(chain.simulatedBones.get(currentBone));
            }
        if (currentBone == stopAfter)
            currentBone = null;
        else
            currentBone = currentBone.getParent();
    }
}

public void groupedRecursiveSegmentSolver(SegmentedArmature startFrom, double dampening, int stabilizationPasses,
        int iteration, double totalIterations) {
    recursiveSegmentSolver(startFrom, dampening, stabilizationPasses, iteration, totalIterations);
    for (SegmentedArmature a : startFrom.pinnedDescendants) {
        for (SegmentedArmature c : a.childSegments) {
            // alignSegmentTipOrientationsFor(startFrom, dampening);
            groupedRecursiveSegmentSolver(c, dampening, stabilizationPasses, iteration, totalIterations);
        }
    }
    // alignSegmentTipOrientationsFor(startFrom, dampening);
}

/**
 * aligns this bone and all relevant childBones to their coresponding
 * simulatedAxes (if any) in the SegmentedArmature
 * 
 * @param b bone to start from
 */
public void iterativelyAlignBonesToSimAxesFrom(WorkingBone[] bonelist, int from) {
    // SegmentedArmature chain = b.parentArmature.boneSegmentMap.get(b);
    // //getChainFor(b);

    for (int i = from; i >= 0; i--) {
        WorkingBone sb = bonelist[i];
        AbstractAxes simulatedLocalAxes = sb.simLocalAxes;
        AbstractBone b = sb.forBone;
        /*if (b.parent != null) {
            // TODO: test robustness / efficiency of avoiding global update
            b.localAxes().localMBasis.rotateTo(simulatedLocalAxes.localMBasis.rotation);
            b.localAxes().markDirty();
            b.localAxes().updateGlobal();
        } else {*/
            b.localAxes().alignLocalsTo(simulatedLocalAxes);
        //}
    }
}

/**
 * align the WorkingBone SimulationAxes to the boneAxes outward from the given
 * bone index
 **/
public void iterativelyAlignSimAxesToBones(WorkingBone[] bonelist, int from) {

    // branching outside of loop in hopes of tiny performance gains

    for (int i = from; i >= 0; i--) {
        WorkingBone sb = bonelist[i];
        /*
         * if (!sb.onChain.isBasePinned()) { sbAxes.alignGlobalsTo(b.localAxes());
         * sbAxes.markDirty(); sbAxes.updateGlobal();
         * cAxes.alignGlobalsTo(b.getMajorRotationAxes()); cAxes.markDirty();
         * cAxes.updateGlobal(); } else {&=
         */
        sb.simLocalAxes.alignLocalsTo(sb.forBone.localAxes());
        sb.simConstraintAxes.alignLocalsTo(sb.forBone.getMajorRotationAxes());
        // }
    }

}

/**
 * given a segmented armature, solves each chain from its pinned tips down to
 * its pinned root.
 * 
 * @param armature
 */
public void recursiveSegmentSolver(SegmentedArmature armature, double dampening, int stabilizationPasses,
        int iteration, double totalIterations) {
    if (armature.childSegments == null && !armature.isTipPinned()) {
        return;
    } else if (!armature.isTipPinned()) {
        for (SegmentedArmature c : armature.childSegments) {
            recursiveSegmentSolver(c, dampening, stabilizationPasses, iteration, totalIterations);
            // c.setProcessed(true);
        }
    }
    QCPSolver(armature, dampening, false, stabilizationPasses, iteration, totalIterations);
}

boolean debug = true;
AbstractBone lastDebugBone = null;

private void QCPSolver(SegmentedArmature chain, double dampening, boolean inverseWeighting, int stabilizationPasses,
        int iteration, double totalIterations) {

    debug = false;

    // lastDebugBone = null;
    AbstractBone startFrom = debug && lastDebugBone != null ? lastDebugBone : chain.segmentTip;
    AbstractBone stopAfter = chain.segmentRoot;

    AbstractBone currentBone = startFrom;
    if (debug && chain.simulatedBones.size() < 2) {

    } else {
        /*
         * if(chain.isTipPinned() && chain.segmentTip.getIKPin().getDepthFalloff() ==
         * 0d) alignSegmentTipOrientationsFor(chain, dampening);
         */
        // System.out.print("---------");
        while (currentBone != null) {
            if (!currentBone.getIKOrientationLock()) {
                chain.updateOptimalRotationToPinnedDescendants(currentBone, dampening, false, stabilizationPasses,
                        iteration, totalIterations);
            }
            if (currentBone == stopAfter)
                currentBone = null;
            else
                currentBone = currentBone.getParent();

            if (debug) {
                lastDebugBone = currentBone;
                break;
            }
        }

    }
}

void rootwardlyUpdateFalloffCacheFrom(AbstractBone forBone) {
    SegmentedArmature current = boneSegmentMap.get(forBone);
    while (current != null) {
        current.createHeadingArrays();
        current = current.getParentSegment();
    }
}

// debug code -- use to set a minimum distance an effector must move
// in order to trigger a chain iteration
double debugMag = 5f;
SGVec_3d lastTargetPos = new SGVec_3d();

/**
 * currently unused
 * 
 * @param enabled
 */
public void setAbilityBiasing(boolean enabled) {
    abilityBiasing = enabled;
}

public boolean getAbilityBiasing() {
    return abilityBiasing;
}

/**
 * returns the rotation that would bring the right-handed orthonormal axes of a
 * into alignment with b
 * 
 * @param a
 * @param b
 * @return
 */
public Rot getRotationBetween(AbstractAxes a, AbstractAxes b) {
    return new Rot(a.x_().heading(), a.y_().heading(), b.x_().heading(), b.y_().heading());
}

public int getDefaultIterations() {
    return IKIterations;
}

public double getDampening() {
    return dampening;
}

boolean monitorPerformance = true;

public void setPerformanceMonitor(boolean state) {
    monitorPerformance = state;
}

public class PerformanceStats {
    int timedCalls = 0;
    int benchmarkWindow = 60;
    int iterationCount = 0;
    float averageSolutionTime = 0;
    float averageIterationTime = 0;
    int solutionCount = 0;
    float iterationsPerSecond = 0f;
    long totalSolutionTime = 0;

    long startTime = 0;

    public void startPerformanceMonitor() {
        monitorPerformance = true;
        if (monitorPerformance) {
            if (timedCalls > benchmarkWindow) {
                performance.resetPerformanceStat();
            }
            startTime = System.nanoTime();
        }
    }

    public void solveFinished(int iterations) {
        if (monitorPerformance) {
            totalSolutionTime += System.nanoTime() - startTime;
            // averageSolutionTime *= solutionCount;
            solutionCount++;
            iterationCount += iterations;

            if (timedCalls > benchmarkWindow) {
                timedCalls = 0;
                performance.printStats();
            }
            timedCalls++;
        }
    }

    public void resetPerformanceStat() {
        startTime = 0;
        iterationCount = 0;
        averageSolutionTime = 0;
        solutionCount = 0;
        iterationsPerSecond = 0f;
        totalSolutionTime = 0;
        averageIterationTime = 0;
    }

    public void printStats() {
        averageSolutionTime = (float) (totalSolutionTime / solutionCount) / 1000000f;
        averageIterationTime = (float) (totalSolutionTime / iterationCount) / 1000000f;
        System.out.println("solution time average: ");
        System.out.println("per call = " + (averageSolutionTime) + "ms");
        System.out.println("per iteration = " + (averageIterationTime) + "ms \n");
    }

}

@Override
public void makeSaveable(SaveManager saveManager) {
    saveManager.addToSaveState(this);
    if (this.localAxes().getParentAxes() != null)
        this.localAxes().getParentAxes().makeSaveable(saveManager);
    else
        this.localAxes().makeSaveable(saveManager);
    this.rootBone.makeSaveable(saveManager);
}

@Override
public JSONObject getSaveJSON(SaveManager saveManager) {
    JSONObject saveJSON = new JSONObject();
    saveJSON.setString("identityHash", this.getIdentityHash());
    saveJSON.setString("localAxes", localAxes().getIdentityHash());
    saveJSON.setString("rootBone", getRootBone().getIdentityHash());
    saveJSON.setInt("defaultIterations", getDefaultIterations());
    saveJSON.setDouble("dampening", this.getDampening());
    // saveJSON.setBoolean("inverseWeighted", this.isInverseWeighted());
    saveJSON.setString("tag", this.getTag());
    return saveJSON;
}

public void loadFromJSONObject(JSONObject j, LoadManager l) {
    try {
        this.localAxes = l.getObjectFor(AbstractAxes.class, j, "localAxes");
        this.rootBone = l.getObjectFor(AbstractBone.class, j, "rootBone");
        if (j.hasKey("defaultIterations"))
            this.IKIterations = j.getInt("defaultIterations");
        if (j.hasKey("dampening"))
            this.dampening = j.getDouble("dampening");
        this.tag = j.getString("tag");
    } catch (Exception e) {
        e.printStackTrace();
    }
}

@Override
public void notifyOfSaveIntent(SaveManager saveManager) {
    this.makeSaveable(saveManager);
}

@Override
public void notifyOfSaveCompletion(SaveManager saveManager) {
    // TODO Auto-generated method stub

}

@Override
public void notifyOfLoadCompletion() {
    this.createRootBone(rootBone);
    refreshArmaturePins();
    regenerateShadowSkeleton();
}

@Override
public boolean isLoading() {
    // TODO Auto-generated method stub
    return false;
}

@Override
public void setLoading(boolean loading) {
    // TODO Auto-generated method stub

}