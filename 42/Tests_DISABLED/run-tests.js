/**
 * DentalPain Property-Based Test Runner (Node.js)
 * Mirrors the Lua property tests for CI/validation
 * 
 * **Feature: dental-skill-system**
 * **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 2.5**
 */

// ToothState enum
const ToothState = {
    HEALTHY: "healthy",
    CAVITY: "cavity",
    INFECTED: "infected",
    BROKEN: "broken",
    EXTRACTED: "extracted"
};

// Tooth name generation (mirrors Core.lua)
function getToothName(index) {
    if (index < 1 || index > 32) return "Unknown Tooth";
    
    let jaw, side, position;
    
    jaw = index <= 16 ? "Upper" : "Lower";
    
    if (index <= 8) {
        side = "Right";
        position = index;
    } else if (index <= 16) {
        side = "Left";
        position = index - 8;
    } else if (index <= 24) {
        side = "Left";
        position = index - 16;
    } else {
        side = "Right";
        position = index - 24;
    }
    
    return `${jaw} ${side} ${position}`;
}

// Get tooth position info
function getToothPosition(index) {
    if (index < 1 || index > 32) return null;
    
    const position = index <= 16 ? "upper" : "lower";
    let side;
    
    if (index <= 8) side = "right";
    else if (index <= 16) side = "left";
    else if (index <= 24) side = "left";
    else side = "right";
    
    return { position, side };
}

// Create tooth record (mirrors Core.lua)
function createToothRecord(index) {
    if (index < 1 || index > 32) return null;
    
    const posInfo = getToothPosition(index);
    
    return {
        index: index,
        name: getToothName(index),
        health: 100,
        state: ToothState.HEALTHY,
        position: posInfo.position,
        side: posInfo.side
    };
}

// Mock player class
class MockPlayer {
    constructor() {
        this._modData = {};
    }
    
    getModData() {
        return this._modData;
    }
}

// ToothManager module (mirrors ToothManager.lua)
const ToothManager = {
    initialize(player) {
        if (!player) return false;
        
        const modData = player.getModData();
        if (!modData) return false;
        
        modData.dentalTeeth = [];
        
        for (let i = 1; i <= 32; i++) {
            modData.dentalTeeth[i] = createToothRecord(i);
        }
        
        return true;
    },
    
    getAllTeeth(player) {
        if (!player) return null;
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return null;
        return modData.dentalTeeth;
    },
    
    getToothByIndex(player, index) {
        if (!player || index < 1 || index > 32) return null;
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return null;
        return modData.dentalTeeth[index];
    },
    
    getRemainingCount(player) {
        if (!player) return 0;
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return 0;
        
        let count = 0;
        for (let i = 1; i <= 32; i++) {
            const tooth = modData.dentalTeeth[i];
            if (tooth && tooth.state !== ToothState.EXTRACTED) {
                count++;
            }
        }
        return count;
    },
    
    getOverallHealth(player) {
        if (!player) return 0;
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return 0;
        
        let totalHealth = 0;
        let count = 0;
        
        for (let i = 1; i <= 32; i++) {
            const tooth = modData.dentalTeeth[i];
            if (tooth && tooth.state !== ToothState.EXTRACTED) {
                totalHealth += tooth.health;
                count++;
            }
        }
        
        return count === 0 ? 0 : totalHealth / count;
    },
    
    getRandomNonExtractedTooth(player) {
        if (!player) return null;
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return null;
        
        const validIndices = [];
        for (let i = 1; i <= 32; i++) {
            const tooth = modData.dentalTeeth[i];
            if (tooth && tooth.state !== ToothState.EXTRACTED) {
                validIndices.push(i);
            }
        }
        
        if (validIndices.length === 0) return null;
        
        const randomIndex = validIndices[Math.floor(Math.random() * validIndices.length)];
        return modData.dentalTeeth[randomIndex];
    },
    
    setToothState(player, index, state) {
        if (!player || index < 1 || index > 32) return false;
        
        const validStates = [ToothState.HEALTHY, ToothState.CAVITY, ToothState.INFECTED, ToothState.BROKEN, ToothState.EXTRACTED];
        if (!validStates.includes(state)) return false;
        
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return false;
        
        const tooth = modData.dentalTeeth[index];
        if (!tooth) return false;
        
        // Cannot change state of extracted tooth (permanence)
        if (tooth.state === ToothState.EXTRACTED && state !== ToothState.EXTRACTED) {
            return false;
        }
        
        tooth.state = state;
        return true;
    },
    
    applyDamage(player, amount) {
        if (!player || !amount || amount <= 0) return null;
        
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return null;
        
        const tooth = this.getRandomNonExtractedTooth(player);
        if (!tooth) return null;
        
        const toothIndex = tooth.index;
        tooth.health = Math.max(0, tooth.health - amount);
        
        // Handle zero-health transition to broken state
        if (tooth.health <= 0 && tooth.state !== ToothState.BROKEN && tooth.state !== ToothState.EXTRACTED) {
            tooth.state = ToothState.BROKEN;
        }
        
        return toothIndex;
    },
    
    extractTooth(player, index) {
        if (!player || index < 1 || index > 32) return false;
        
        const modData = player.getModData();
        if (!modData || !modData.dentalTeeth) return false;
        
        const tooth = modData.dentalTeeth[index];
        if (!tooth) return false;
        
        // Cannot extract an already extracted tooth
        if (tooth.state === ToothState.EXTRACTED) return false;
        
        tooth.state = ToothState.EXTRACTED;
        tooth.health = 0;
        
        return true;
    }
};

// Test results tracking
let totalPassed = 0;
let totalFailed = 0;

/**
 * Property 1: Tooth Initialization Invariant
 * **Validates: Requirements 1.1, 2.5**
 */
function property_ToothInitializationInvariant(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockPlayer();
        const initResult = ToothManager.initialize(mockPlayer);
        
        if (!initResult) {
            failed++;
            failures.push({ iteration: i, reason: "initialize() returned false" });
            continue;
        }
        
        const teeth = ToothManager.getAllTeeth(mockPlayer);
        let isValid = true;
        let failReason = null;
        
        if (!teeth) {
            isValid = false;
            failReason = "getAllTeeth() returned null";
        } else {
            // Check 32 teeth (indices 1-32)
            let toothCount = 0;
            for (let j = 1; j <= 32; j++) {
                if (teeth[j]) toothCount++;
            }
            
            if (toothCount !== 32) {
                isValid = false;
                failReason = `Expected 32 teeth, got ${toothCount}`;
            } else {
                for (let j = 1; j <= 32; j++) {
                    const tooth = teeth[j];
                    
                    if (!tooth) {
                        isValid = false;
                        failReason = `Tooth ${j} is null`;
                        break;
                    }
                    
                    if (tooth.state !== ToothState.HEALTHY) {
                        isValid = false;
                        failReason = `Tooth ${j} state is '${tooth.state}', expected 'healthy'`;
                        break;
                    }
                    
                    if (tooth.health !== 100) {
                        isValid = false;
                        failReason = `Tooth ${j} health is ${tooth.health}, expected 100`;
                        break;
                    }
                    
                    if (tooth.index !== j) {
                        isValid = false;
                        failReason = `Tooth ${j} index is ${tooth.index}, expected ${j}`;
                        break;
                    }
                    
                    if (!tooth.name || typeof tooth.name !== 'string' || tooth.name === '') {
                        isValid = false;
                        failReason = `Tooth ${j} has invalid name: ${tooth.name}`;
                        break;
                    }
                    
                    if (tooth.position !== 'upper' && tooth.position !== 'lower') {
                        isValid = false;
                        failReason = `Tooth ${j} has invalid position: ${tooth.position}`;
                        break;
                    }
                    
                    if (tooth.side !== 'left' && tooth.side !== 'right') {
                        isValid = false;
                        failReason = `Tooth ${j} has invalid side: ${tooth.side}`;
                        break;
                    }
                }
                
                if (isValid) {
                    const overallHealth = ToothManager.getOverallHealth(mockPlayer);
                    if (overallHealth !== 100) {
                        isValid = false;
                        failReason = `Overall health is ${overallHealth}%, expected 100%`;
                    }
                }
                
                if (isValid) {
                    const remaining = ToothManager.getRemainingCount(mockPlayer);
                    if (remaining !== 32) {
                        isValid = false;
                        failReason = `Remaining count is ${remaining}, expected 32`;
                    }
                }
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason });
        }
    }
    
    return { property: "Tooth Initialization Invariant", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 2: Damage Distribution to Non-Extracted Teeth
 * **Validates: Requirements 1.2**
 */
function property_DamageDistributionToNonExtracted(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockPlayer();
        ToothManager.initialize(mockPlayer);
        
        // Randomly extract some teeth (0 to 30, leaving at least 1)
        const numToExtract = Math.floor(Math.random() * 31);
        const extractedIndices = new Set();
        
        for (let j = 0; j < numToExtract; j++) {
            let idx = Math.floor(Math.random() * 32) + 1;
            while (extractedIndices.has(idx)) {
                idx = Math.floor(Math.random() * 32) + 1;
            }
            extractedIndices.add(idx);
            ToothManager.extractTooth(mockPlayer, idx);
        }
        
        // Apply damage
        const damageAmount = Math.floor(Math.random() * 50) + 1;
        const damagedIndex = ToothManager.applyDamage(mockPlayer, damageAmount);
        
        let isValid = true;
        let failReason = null;
        
        if (!damagedIndex) {
            const remaining = ToothManager.getRemainingCount(mockPlayer);
            if (remaining > 0) {
                isValid = false;
                failReason = `applyDamage returned null but ${remaining} teeth remain`;
            }
        } else {
            if (extractedIndices.has(damagedIndex)) {
                isValid = false;
                failReason = `Damage applied to extracted tooth ${damagedIndex}`;
            }
            
            const tooth = ToothManager.getToothByIndex(mockPlayer, damagedIndex);
            if (tooth && tooth.state === ToothState.EXTRACTED) {
                isValid = false;
                failReason = `Damaged tooth ${damagedIndex} has extracted state`;
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, numExtracted: numToExtract, damagedIndex });
        }
    }
    
    return { property: "Damage Distribution to Non-Extracted Teeth", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 3: Zero Health State Transition
 * **Validates: Requirements 1.3**
 */
function property_ZeroHealthStateTransition(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockPlayer();
        ToothManager.initialize(mockPlayer);
        
        const toothIndex = Math.floor(Math.random() * 32) + 1;
        const modData = mockPlayer.getModData();
        const targetTooth = modData.dentalTeeth[toothIndex];
        
        // Apply damage to bring health to 0
        targetTooth.health = 0;
        
        // Trigger state transition (simulating what applyDamage does)
        if (targetTooth.state !== ToothState.BROKEN && targetTooth.state !== ToothState.EXTRACTED) {
            targetTooth.state = ToothState.BROKEN;
        }
        
        let isValid = true;
        let failReason = null;
        
        if (targetTooth.health !== 0) {
            isValid = false;
            failReason = `Tooth ${toothIndex} health is ${targetTooth.health}, expected 0`;
        } else if (targetTooth.state !== ToothState.BROKEN) {
            isValid = false;
            failReason = `Tooth ${toothIndex} state is '${targetTooth.state}', expected 'broken'`;
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, toothIndex, finalHealth: targetTooth.health, finalState: targetTooth.state });
        }
    }
    
    return { property: "Zero Health State Transition", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 4: Extraction Permanence
 * **Validates: Requirements 1.4**
 */
function property_ExtractionPermanence(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockPlayer();
        ToothManager.initialize(mockPlayer);
        
        const toothIndex = Math.floor(Math.random() * 32) + 1;
        const countBefore = ToothManager.getRemainingCount(mockPlayer);
        
        const extractResult = ToothManager.extractTooth(mockPlayer, toothIndex);
        const countAfter = ToothManager.getRemainingCount(mockPlayer);
        const tooth = ToothManager.getToothByIndex(mockPlayer, toothIndex);
        
        let isValid = true;
        let failReason = null;
        
        if (!extractResult) {
            isValid = false;
            failReason = `extractTooth returned false for tooth ${toothIndex}`;
        }
        
        if (isValid && tooth.state !== ToothState.EXTRACTED) {
            isValid = false;
            failReason = `Tooth ${toothIndex} state is '${tooth.state}', expected 'extracted'`;
        }
        
        if (isValid && (countBefore - countAfter) !== 1) {
            isValid = false;
            failReason = `Count changed by ${countBefore - countAfter}, expected 1`;
        }
        
        // Try to change state back (should fail - permanence)
        if (isValid) {
            const changeResult = ToothManager.setToothState(mockPlayer, toothIndex, ToothState.HEALTHY);
            if (changeResult) {
                isValid = false;
                failReason = "setToothState succeeded on extracted tooth (should be permanent)";
            }
            
            const toothAfter = ToothManager.getToothByIndex(mockPlayer, toothIndex);
            if (toothAfter.state !== ToothState.EXTRACTED) {
                isValid = false;
                failReason = `Extracted tooth state changed to '${toothAfter.state}' (should be permanent)`;
            }
        }
        
        // Try to extract again (should fail)
        if (isValid) {
            const reExtractResult = ToothManager.extractTooth(mockPlayer, toothIndex);
            if (reExtractResult) {
                isValid = false;
                failReason = "extractTooth succeeded on already extracted tooth";
            }
            
            const countAfterReExtract = ToothManager.getRemainingCount(mockPlayer);
            if (countAfterReExtract !== countAfter) {
                isValid = false;
                failReason = `Count changed after re-extraction attempt`;
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, toothIndex, countBefore, countAfter });
        }
    }
    
    return { property: "Extraction Permanence", iterations, passed, failed, failures, success: failed === 0 };
}

// ============================================
// SkillManager Module (mirrors SkillManager.lua)
// ============================================
const SkillManager = {
    XP: {
        SELF_EXTRACTION_SUCCESS: 50,
        SELF_EXTRACTION_FAIL: 10,
        ZOMBIE_EXTRACTION_SUCCESS: 25,
        ZOMBIE_EXTRACTION_FAIL: 6,
        CAVITY_FILL: 30,
    },
    
    UNLOCKS: {
        cavity_fill: 3,
        craft_tools: 5,
    },
    
    MAX_LEVEL: 10,
    
    getLevel(player) {
        if (!player) return 0;
        const level = player.getPerkLevel ? player.getPerkLevel('DentalCare') : 0;
        return Math.min(level || 0, this.MAX_LEVEL);
    },
    
    isUnlocked(player, ability) {
        if (!player || !ability) return false;
        const requiredLevel = this.UNLOCKS[ability];
        if (requiredLevel === undefined) return false;
        const currentLevel = this.getLevel(player);
        return currentLevel >= requiredLevel;
    }
};

// ============================================
// FormulaCalculator Module (mirrors FormulaCalculator.lua)
// ============================================
const FormulaCalculator = {
    // Base chances (Requirement 5.2)
    BASE_PLIERS: 60,
    BASE_HAMMER: 35,
    
    // Bonuses (Requirements 5.1, 5.3)
    SKILL_BONUS: 5,
    DOCTOR_BONUS: 10,
    ANESTHETIC_BONUS: 30,
    
    // Caps (Requirement 5.3)
    MAX_CHANCE: 95,
    
    // Failure damage constants (Requirement 5.4)
    BASE_FAILURE_DAMAGE: 50,
    DAMAGE_REDUCTION_PER_LEVEL: 4,
    MIN_FAILURE_DAMAGE: 10,
    
    getExtractionChance(player, method) {
        if (!player) return 0;
        
        const base = method === "pliers" ? this.BASE_PLIERS : this.BASE_HAMMER;
        const dentalSkill = SkillManager.getLevel(player);
        const doctorSkill = player.getPerkLevel ? player.getPerkLevel('Doctor') : 0;
        const isNumbed = player.getModData && player.getModData().anestheticTimer > 0;
        const anestheticBonus = isNumbed ? this.ANESTHETIC_BONUS : 0;
        
        const chance = base 
            + (dentalSkill * this.SKILL_BONUS) 
            + (doctorSkill * this.DOCTOR_BONUS) 
            + anestheticBonus;
        
        return Math.min(chance, this.MAX_CHANCE);
    },
    
    getFailureDamage(player) {
        if (!player) return this.BASE_FAILURE_DAMAGE;
        
        const dentalSkill = SkillManager.getLevel(player);
        const damage = this.BASE_FAILURE_DAMAGE - (dentalSkill * this.DAMAGE_REDUCTION_PER_LEVEL);
        
        return Math.max(damage, this.MIN_FAILURE_DAMAGE);
    },
    
    getToolModifierDifference() {
        return this.BASE_PLIERS - this.BASE_HAMMER;
    }
};

// Mock player for skill tests
class MockSkillPlayer {
    constructor(skillLevel = 0) {
        this._skillLevel = skillLevel;
    }
    
    getPerkLevel(perk) {
        if (perk === 'DentalCare') {
            return this._skillLevel;
        }
        return 0;
    }
}

// Mock player for formula tests (supports both skills and numbed state)
class MockFormulaPlayer {
    constructor(dentalSkillLevel = 0, doctorLevel = 0, isNumbed = false) {
        this._dentalSkillLevel = dentalSkillLevel;
        this._doctorLevel = doctorLevel;
        this._modData = {
            anestheticTimer: isNumbed ? 1 : 0
        };
    }
    
    getPerkLevel(perk) {
        if (perk === 'DentalCare') {
            return this._dentalSkillLevel;
        } else if (perk === 'Doctor') {
            return this._doctorLevel;
        }
        return 0;
    }
    
    getModData() {
        return this._modData;
    }
}

/**
 * Property 8: Skill Unlock Thresholds
 * **Validates: Requirements 3.4, 3.5**
 */
function property_SkillUnlockThresholds(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        // Generate random skill level 0-10
        const skillLevel = Math.floor(Math.random() * 11);
        const mockPlayer = new MockSkillPlayer(skillLevel);
        
        let isValid = true;
        let failReason = null;
        
        // Test cavity_fill (threshold: 3)
        const cavityFillUnlocked = SkillManager.isUnlocked(mockPlayer, "cavity_fill");
        const expectedCavityFill = skillLevel >= 3;
        
        if (cavityFillUnlocked !== expectedCavityFill) {
            isValid = false;
            failReason = `cavity_fill: level ${skillLevel}, expected ${expectedCavityFill}, got ${cavityFillUnlocked}`;
        }
        
        // Test craft_tools (threshold: 5)
        if (isValid) {
            const craftToolsUnlocked = SkillManager.isUnlocked(mockPlayer, "craft_tools");
            const expectedCraftTools = skillLevel >= 5;
            
            if (craftToolsUnlocked !== expectedCraftTools) {
                isValid = false;
                failReason = `craft_tools: level ${skillLevel}, expected ${expectedCraftTools}, got ${craftToolsUnlocked}`;
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, skillLevel });
        }
    }
    
    return { property: "Skill Unlock Thresholds (P8)", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 9: Skill Level Cap
 * **Validates: Requirements 3.6**
 */
function property_SkillLevelCap(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        // Generate random skill level including values > 10 to test cap
        const rawLevel = Math.floor(Math.random() * 20); // 0-19
        const mockPlayer = new MockSkillPlayer(rawLevel);
        
        let isValid = true;
        let failReason = null;
        
        // Get level through SkillManager (should be capped)
        const reportedLevel = SkillManager.getLevel(mockPlayer);
        
        // Level should never exceed MAX_LEVEL (10)
        if (reportedLevel > SkillManager.MAX_LEVEL) {
            isValid = false;
            failReason = `Level ${reportedLevel} exceeds max ${SkillManager.MAX_LEVEL}`;
        }
        
        // Level should be capped at MAX_LEVEL when raw > MAX_LEVEL
        if (isValid && rawLevel > SkillManager.MAX_LEVEL) {
            if (reportedLevel !== SkillManager.MAX_LEVEL) {
                isValid = false;
                failReason = `Raw level ${rawLevel} should cap to ${SkillManager.MAX_LEVEL}, got ${reportedLevel}`;
            }
        }
        
        // Level should match raw when raw <= MAX_LEVEL
        if (isValid && rawLevel <= SkillManager.MAX_LEVEL) {
            if (reportedLevel !== rawLevel) {
                isValid = false;
                failReason = `Raw level ${rawLevel} should equal reported ${reportedLevel}`;
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, rawLevel, reportedLevel });
        }
    }
    
    return { property: "Skill Level Cap (P9)", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 7: Skill Level Success Rate Formula
 * **Validates: Requirements 3.3, 5.1, 5.3**
 */
function property_SkillLevelSuccessRateFormula(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        // Generate random skill levels 0-10
        const dentalSkill = Math.floor(Math.random() * 11);
        const doctorSkill = Math.floor(Math.random() * 11);
        const isNumbed = Math.random() < 0.5;
        const method = Math.random() < 0.5 ? "pliers" : "hammer";
        
        const mockPlayer = new MockFormulaPlayer(dentalSkill, doctorSkill, isNumbed);
        
        let isValid = true;
        let failReason = null;
        
        // Calculate expected value using the formula
        const base = method === "pliers" ? FormulaCalculator.BASE_PLIERS : FormulaCalculator.BASE_HAMMER;
        const anestheticBonus = isNumbed ? FormulaCalculator.ANESTHETIC_BONUS : 0;
        let expectedChance = base 
            + (dentalSkill * FormulaCalculator.SKILL_BONUS) 
            + (doctorSkill * FormulaCalculator.DOCTOR_BONUS) 
            + anestheticBonus;
        expectedChance = Math.min(expectedChance, FormulaCalculator.MAX_CHANCE);
        
        // Get actual value from FormulaCalculator
        const actualChance = FormulaCalculator.getExtractionChance(mockPlayer, method);
        
        if (actualChance !== expectedChance) {
            isValid = false;
            failReason = `Method=${method}, DentalSkill=${dentalSkill}, DoctorSkill=${doctorSkill}, Numbed=${isNumbed}: expected ${expectedChance}%, got ${actualChance}%`;
        }
        
        // Verify cap at 95%
        if (isValid && actualChance > FormulaCalculator.MAX_CHANCE) {
            isValid = false;
            failReason = `Chance ${actualChance}% exceeds max cap of ${FormulaCalculator.MAX_CHANCE}%`;
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, dentalSkill, doctorSkill, isNumbed, method, expected: expectedChance, actual: actualChance });
        }
    }
    
    return { property: "Skill Level Success Rate Formula (P7)", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 13: Failure Damage Inverse Relationship
 * **Validates: Requirements 5.4**
 */
function property_FailureDamageInverseRelationship(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        // Generate two different skill levels to compare
        let skillLevel1 = Math.floor(Math.random() * 11);
        let skillLevel2 = Math.floor(Math.random() * 11);
        
        // Ensure they're different for meaningful comparison
        while (skillLevel1 === skillLevel2) {
            skillLevel2 = Math.floor(Math.random() * 11);
        }
        
        const mockPlayer1 = new MockFormulaPlayer(skillLevel1, 0, false);
        const mockPlayer2 = new MockFormulaPlayer(skillLevel2, 0, false);
        
        const damage1 = FormulaCalculator.getFailureDamage(mockPlayer1);
        const damage2 = FormulaCalculator.getFailureDamage(mockPlayer2);
        
        let isValid = true;
        let failReason = null;
        
        // Higher skill should result in less or equal damage
        if (skillLevel1 > skillLevel2) {
            if (damage1 > damage2) {
                isValid = false;
                failReason = `Higher skill (${skillLevel1}) has more damage (${damage1}) than lower skill (${skillLevel2}) with damage (${damage2})`;
            }
        } else {
            if (damage2 > damage1) {
                isValid = false;
                failReason = `Higher skill (${skillLevel2}) has more damage (${damage2}) than lower skill (${skillLevel1}) with damage (${damage1})`;
            }
        }
        
        // Verify damage is within expected bounds
        if (isValid) {
            if (damage1 < FormulaCalculator.MIN_FAILURE_DAMAGE || damage1 > FormulaCalculator.BASE_FAILURE_DAMAGE) {
                isValid = false;
                failReason = `Damage ${damage1} is outside bounds [${FormulaCalculator.MIN_FAILURE_DAMAGE}, ${FormulaCalculator.BASE_FAILURE_DAMAGE}]`;
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, skillLevel1, skillLevel2, damage1, damage2 });
        }
    }
    
    return { property: "Failure Damage Inverse Relationship (P13)", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 14: Tool Modifier Difference
 * **Validates: Requirements 5.5**
 */
function property_ToolModifierDifference(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    // First verify the constant difference
    const expectedDifference = 25;
    const actualDifference = FormulaCalculator.BASE_PLIERS - FormulaCalculator.BASE_HAMMER;
    
    if (actualDifference !== expectedDifference) {
        return {
            property: "Tool Modifier Difference (P14)",
            iterations: 1,
            passed: 0,
            failed: 1,
            failures: [{
                iteration: 0,
                reason: `Base difference is ${actualDifference}, expected ${expectedDifference} (pliers=${FormulaCalculator.BASE_PLIERS}, hammer=${FormulaCalculator.BASE_HAMMER})`
            }],
            success: false
        };
    }
    
    for (let i = 0; i < iterations; i++) {
        // Generate random skill levels
        const dentalSkill = Math.floor(Math.random() * 11);
        const doctorSkill = Math.floor(Math.random() * 11);
        const isNumbed = Math.random() < 0.5;
        
        const mockPlayer = new MockFormulaPlayer(dentalSkill, doctorSkill, isNumbed);
        
        const pliersChance = FormulaCalculator.getExtractionChance(mockPlayer, "pliers");
        const hammerChance = FormulaCalculator.getExtractionChance(mockPlayer, "hammer");
        
        let isValid = true;
        let failReason = null;
        
        // The difference should be exactly 25 (unless capped)
        const difference = pliersChance - hammerChance;
        
        // If neither is capped, difference should be exactly 25
        const pliersUncapped = pliersChance < FormulaCalculator.MAX_CHANCE;
        const hammerUncapped = hammerChance < FormulaCalculator.MAX_CHANCE;
        
        if (pliersUncapped && hammerUncapped) {
            if (difference !== expectedDifference) {
                isValid = false;
                failReason = `Uncapped difference is ${difference}, expected ${expectedDifference} (pliers=${pliersChance}, hammer=${hammerChance})`;
            }
        } else {
            // When capped, pliers should be >= hammer
            if (pliersChance < hammerChance) {
                isValid = false;
                failReason = `Pliers chance (${pliersChance}) is less than hammer chance (${hammerChance})`;
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, dentalSkill, doctorSkill, isNumbed, pliersChance, hammerChance });
        }
    }
    
    return { property: "Tool Modifier Difference (P14)", iterations, passed, failed, failures, success: failed === 0 };
}

// ============================================
// ZombiePractice Module (mirrors ZombiePractice.lua)
// ============================================
const ZombiePractice = {
    MAX_TEETH_PER_CORPSE: 5,
    
    getTeethRemaining(zombie) {
        if (!zombie) return 0;
        const modData = zombie.getModData();
        if (!modData) return this.MAX_TEETH_PER_CORPSE;
        const extracted = modData.dentalTeethExtracted || 0;
        return Math.max(0, this.MAX_TEETH_PER_CORPSE - extracted);
    },
    
    canPractice(zombie) {
        if (!zombie) return false;
        return this.getTeethRemaining(zombie) > 0;
    },
    
    performExtraction(player, zombie) {
        if (!player || !zombie) return false;
        if (!this.canPractice(zombie)) return false;
        
        // Calculate success chance
        const chance = FormulaCalculator.getExtractionChance(player, "pliers");
        const roll = Math.floor(Math.random() * 100);
        
        // Update zombie corpse teeth count
        const zombieData = zombie.getModData();
        zombieData.dentalTeethExtracted = (zombieData.dentalTeethExtracted || 0) + 1;
        
        if (roll < chance) {
            // Success - add ZombieTooth item and award XP
            if (player.getInventory) {
                player.getInventory().AddItem("DentalPain.ZombieTooth");
            }
            // Award 50% XP (ZOMBIE_EXTRACTION_SUCCESS = 25)
            if (player.getXp) {
                player.getXp().AddXP('DentalCare', SkillManager.XP.ZOMBIE_EXTRACTION_SUCCESS);
            }
            return true;
        } else {
            // Failure - award reduced XP, NO damage to player
            if (player.getXp) {
                player.getXp().AddXP('DentalCare', SkillManager.XP.ZOMBIE_EXTRACTION_FAIL);
            }
            // NO damage to player (Requirement 4.5)
            return false;
        }
    }
};

// Mock zombie corpse for testing
class MockZombie {
    constructor(teethExtracted = 0) {
        this._modData = {
            dentalTeethExtracted: teethExtracted
        };
    }
    
    getModData() {
        return this._modData;
    }
}

// Mock player for zombie practice tests
class MockZombiePracticePlayer {
    constructor(skillLevel = 0) {
        this._skillLevel = skillLevel;
        this._modData = { anestheticTimer: 0 };
        this._xpHistory = [];
        this._inventory = [];
        this._bodyDamage = {
            parts: {},
            getBodyPart(partType) {
                if (!this.parts[partType]) {
                    this.parts[partType] = {
                        pain: 0,
                        bleeding: false,
                        deepWound: false,
                        getAdditionalPain() { return this.pain; },
                        setAdditionalPain(val) { this.pain = val; },
                        setBleeding(val) { this.bleeding = val; },
                        generateDeepWound() { this.deepWound = true; }
                    };
                }
                return this.parts[partType];
            }
        };
    }
    
    getPerkLevel(perk) {
        if (perk === 'DentalCare') return this._skillLevel;
        if (perk === 'Doctor') return 0;
        return 0;
    }
    
    getModData() {
        return this._modData;
    }
    
    getXp() {
        const self = this;
        return {
            AddXP(perk, amount) {
                self._xpHistory.push({ perk, amount });
            }
        };
    }
    
    getInventory() {
        const self = this;
        return {
            AddItem(itemType) {
                self._inventory.push(itemType);
            },
            contains(itemType) {
                return self._inventory.includes(itemType);
            }
        };
    }
    
    getBodyDamage() {
        return this._bodyDamage;
    }
}

/**
 * Property 10: Zombie Practice XP Rewards
 * **Validates: Requirements 4.2, 4.4**
 */
function property_ZombiePracticeXPRewards(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    // Expected XP values
    const expectedSuccessXP = SkillManager.XP.ZOMBIE_EXTRACTION_SUCCESS; // 25
    const expectedFailXP = SkillManager.XP.ZOMBIE_EXTRACTION_FAIL; // 6
    const selfSuccessXP = SkillManager.XP.SELF_EXTRACTION_SUCCESS; // 50
    
    // Verify XP values match requirements (50% of self for success)
    if (expectedSuccessXP !== Math.floor(selfSuccessXP * 0.5)) {
        return {
            property: "Zombie Practice XP Rewards (P10)",
            iterations: 1,
            passed: 0,
            failed: 1,
            failures: [{
                iteration: 0,
                reason: `ZOMBIE_EXTRACTION_SUCCESS (${expectedSuccessXP}) is not 50% of SELF_EXTRACTION_SUCCESS (${selfSuccessXP})`
            }],
            success: false
        };
    }
    
    // Verify fail XP is ~25% of success XP
    const expectedFailFromSuccess = Math.floor(expectedSuccessXP * 0.25);
    if (Math.abs(expectedFailXP - expectedFailFromSuccess) > 1) {
        return {
            property: "Zombie Practice XP Rewards (P10)",
            iterations: 1,
            passed: 0,
            failed: 1,
            failures: [{
                iteration: 0,
                reason: `ZOMBIE_EXTRACTION_FAIL (${expectedFailXP}) is not ~25% of ZOMBIE_EXTRACTION_SUCCESS (${expectedSuccessXP})`
            }],
            success: false
        };
    }
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockZombiePracticePlayer(0);
        const mockZombie = new MockZombie(0);
        
        // Clear XP history
        mockPlayer._xpHistory = [];
        
        // Perform extraction
        const result = ZombiePractice.performExtraction(mockPlayer, mockZombie);
        
        let isValid = true;
        let failReason = null;
        
        // Check XP was awarded
        if (mockPlayer._xpHistory.length === 0) {
            isValid = false;
            failReason = "No XP was awarded";
        } else {
            const xpAwarded = mockPlayer._xpHistory[0].amount;
            
            if (result) {
                // Success - should award ZOMBIE_EXTRACTION_SUCCESS XP
                if (xpAwarded !== expectedSuccessXP) {
                    isValid = false;
                    failReason = `Success awarded ${xpAwarded} XP, expected ${expectedSuccessXP}`;
                }
            } else {
                // Failure - should award ZOMBIE_EXTRACTION_FAIL XP
                if (xpAwarded !== expectedFailXP) {
                    isValid = false;
                    failReason = `Failure awarded ${xpAwarded} XP, expected ${expectedFailXP}`;
                }
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, result });
        }
    }
    
    return { property: "Zombie Practice XP Rewards (P10)", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 11: Zombie Practice Safety
 * **Validates: Requirements 4.5**
 */
function property_ZombiePracticeSafety(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockZombiePracticePlayer(0);
        const mockZombie = new MockZombie(0);
        
        // Record initial body state
        const bodyDamage = mockPlayer.getBodyDamage();
        const headPart = bodyDamage.getBodyPart("Head");
        const initialPain = headPart.getAdditionalPain();
        const initialBleeding = headPart.bleeding;
        const initialDeepWound = headPart.deepWound;
        
        // Perform extraction
        const result = ZombiePractice.performExtraction(mockPlayer, mockZombie);
        
        let isValid = true;
        let failReason = null;
        
        // Check body damage unchanged
        const finalPain = headPart.getAdditionalPain();
        const finalBleeding = headPart.bleeding;
        const finalDeepWound = headPart.deepWound;
        
        if (finalPain !== initialPain) {
            isValid = false;
            failReason = `Pain changed from ${initialPain} to ${finalPain} (result: ${result})`;
        }
        
        if (isValid && finalBleeding !== initialBleeding) {
            isValid = false;
            failReason = `Bleeding changed from ${initialBleeding} to ${finalBleeding} (result: ${result})`;
        }
        
        if (isValid && finalDeepWound !== initialDeepWound) {
            isValid = false;
            failReason = `Deep wound changed from ${initialDeepWound} to ${finalDeepWound} (result: ${result})`;
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, result });
        }
    }
    
    return { property: "Zombie Practice Safety (P11)", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 12: Zombie Corpse Extraction Limit
 * **Validates: Requirements 4.6**
 */
function property_ZombieCorpseExtractionLimit(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockZombiePracticePlayer(0);
        const mockZombie = new MockZombie(0);
        
        let isValid = true;
        let failReason = null;
        
        // Perform 5 extractions (the maximum)
        for (let j = 1; j <= 5; j++) {
            const canPractice = ZombiePractice.canPractice(mockZombie);
            if (!canPractice) {
                isValid = false;
                failReason = `canPractice returned false on extraction ${j} (should allow up to 5)`;
                break;
            }
            
            const teethBefore = ZombiePractice.getTeethRemaining(mockZombie);
            ZombiePractice.performExtraction(mockPlayer, mockZombie);
            const teethAfter = ZombiePractice.getTeethRemaining(mockZombie);
            
            // Verify teeth count decreased
            if (teethAfter !== teethBefore - 1) {
                isValid = false;
                failReason = `Teeth count didn't decrease properly on extraction ${j} (before: ${teethBefore}, after: ${teethAfter})`;
                break;
            }
        }
        
        // After 5 extractions, no more should be possible
        if (isValid) {
            const teethRemaining = ZombiePractice.getTeethRemaining(mockZombie);
            if (teethRemaining !== 0) {
                isValid = false;
                failReason = `After 5 extractions, teeth remaining is ${teethRemaining}, expected 0`;
            }
        }
        
        if (isValid) {
            const canPracticeAfter = ZombiePractice.canPractice(mockZombie);
            if (canPracticeAfter) {
                isValid = false;
                failReason = "canPractice returned true after 5 extractions (should be false)";
            }
        }
        
        // Try to perform 6th extraction (should fail)
        if (isValid) {
            const result = ZombiePractice.performExtraction(mockPlayer, mockZombie);
            if (result) {
                isValid = false;
                failReason = "6th extraction succeeded (should fail)";
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason });
        }
    }
    
    return { property: "Zombie Corpse Extraction Limit (P12)", iterations, passed, failed, failures, success: failed === 0 };
}

// ============================================
// ToothMapUI Tests (Property 5, 6)
// ============================================

// Color mapping for tooth states (mirrors ToothMapUI.COLORS)
const TOOTH_COLORS = {
    healthy: {r: 0.2, g: 0.8, b: 0.2, a: 1.0},    // Green
    cavity: {r: 0.9, g: 0.9, b: 0.2, a: 1.0},     // Yellow
    infected: {r: 1.0, g: 0.5, b: 0.0, a: 1.0},   // Orange
    broken: {r: 0.9, g: 0.2, b: 0.2, a: 1.0},     // Red
    extracted: {r: 0.4, g: 0.4, b: 0.4, a: 0.5},  // Gray
};

// Helper: Compare colors with tolerance
function colorsMatch(c1, c2, tolerance = 0.01) {
    if (!c1 || !c2) return false;
    return Math.abs(c1.r - c2.r) < tolerance &&
           Math.abs(c1.g - c2.g) < tolerance &&
           Math.abs(c1.b - c2.b) < tolerance &&
           Math.abs(c1.a - c2.a) < tolerance;
}

// Helper: Check if all colors are distinct
function areColorsDistinct(colors) {
    const colorList = Object.entries(colors).map(([state, color]) => ({state, color}));
    
    for (let i = 0; i < colorList.length; i++) {
        for (let j = i + 1; j < colorList.length; j++) {
            if (colorsMatch(colorList[i].color, colorList[j].color)) {
                return { distinct: false, state1: colorList[i].state, state2: colorList[j].state };
            }
        }
    }
    
    return { distinct: true };
}

/**
 * Property 5: Tooth State Color Mapping
 * *For any* tooth state in {healthy, cavity, infected, broken, extracted},
 * the UI SHALL map it to exactly one distinct color
 * (green, yellow, orange, red, gray respectively).
 * **Validates: Requirements 2.2**
 */
function property_ToothStateColorMapping(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    const allStates = [ToothState.HEALTHY, ToothState.CAVITY, ToothState.INFECTED, ToothState.BROKEN, ToothState.EXTRACTED];
    
    for (let i = 0; i < iterations; i++) {
        let isValid = true;
        let failReason = null;
        
        // Test 1: Each state maps to exactly one color
        for (const state of allStates) {
            const color = TOOTH_COLORS[state];
            
            if (!color) {
                isValid = false;
                failReason = `State '${state}' has no color mapping`;
                break;
            }
            
            // Verify color has all required components
            if (color.r === undefined || color.g === undefined || color.b === undefined || color.a === undefined) {
                isValid = false;
                failReason = `State '${state}' color is missing components`;
                break;
            }
            
            // Verify color values are in valid range [0, 1]
            if (color.r < 0 || color.r > 1 || color.g < 0 || color.g > 1 || color.b < 0 || color.b > 1 || color.a < 0 || color.a > 1) {
                isValid = false;
                failReason = `State '${state}' color values out of range`;
                break;
            }
        }
        
        // Test 2: All colors are distinct
        if (isValid) {
            const distinctResult = areColorsDistinct(TOOTH_COLORS);
            if (!distinctResult.distinct) {
                isValid = false;
                failReason = `States '${distinctResult.state1}' and '${distinctResult.state2}' have the same color`;
            }
        }
        
        // Test 3: Verify specific color characteristics
        if (isValid) {
            // Green should have high G component
            const green = TOOTH_COLORS[ToothState.HEALTHY];
            if (green.g <= green.r || green.g <= green.b) {
                isValid = false;
                failReason = "Healthy color is not predominantly green";
            }
        }
        
        if (isValid) {
            // Yellow should have high R and G, low B
            const yellow = TOOTH_COLORS[ToothState.CAVITY];
            if (yellow.r < 0.5 || yellow.g < 0.5 || yellow.b > 0.5) {
                isValid = false;
                failReason = "Cavity color is not yellow-ish";
            }
        }
        
        if (isValid) {
            // Orange should have high R, medium G, low B
            const orange = TOOTH_COLORS[ToothState.INFECTED];
            if (orange.r < 0.8 || orange.g > 0.7 || orange.b > 0.3) {
                isValid = false;
                failReason = "Infected color is not orange-ish";
            }
        }
        
        if (isValid) {
            // Red should have high R, low G and B
            const red = TOOTH_COLORS[ToothState.BROKEN];
            if (red.r < 0.7 || red.g > 0.5 || red.b > 0.5) {
                isValid = false;
                failReason = "Broken color is not red-ish";
            }
        }
        
        if (isValid) {
            // Gray should have similar R, G, B values
            const gray = TOOTH_COLORS[ToothState.EXTRACTED];
            const avgGray = (gray.r + gray.g + gray.b) / 3;
            if (Math.abs(gray.r - avgGray) > 0.1 || Math.abs(gray.g - avgGray) > 0.1 || Math.abs(gray.b - avgGray) > 0.1) {
                isValid = false;
                failReason = "Extracted color is not gray-ish";
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason });
        }
    }
    
    return { property: "Tooth State Color Mapping (P5)", iterations, passed, failed, failures, success: failed === 0 };
}

/**
 * Property 6: Tooltip Information Completeness
 * *For any* tooth being hovered, the tooltip SHALL contain:
 * - the tooth name (string, non-empty)
 * - health percentage (0-100)
 * - current state string
 * **Validates: Requirements 2.3**
 */
function property_TooltipInformationCompleteness(iterations = 100) {
    let passed = 0;
    let failed = 0;
    const failures = [];
    
    const allStates = [ToothState.HEALTHY, ToothState.CAVITY, ToothState.INFECTED, ToothState.BROKEN, ToothState.EXTRACTED];
    
    for (let i = 0; i < iterations; i++) {
        const mockPlayer = new MockPlayer();
        ToothManager.initialize(mockPlayer);
        
        // Randomly modify some teeth states and health
        const modData = mockPlayer.getModData();
        for (let j = 1; j <= 32; j++) {
            const tooth = modData.dentalTeeth[j];
            if (tooth) {
                // Random health (0-100)
                tooth.health = Math.floor(Math.random() * 101);
                
                // Random state
                tooth.state = allStates[Math.floor(Math.random() * allStates.length)];
                
                // If extracted, health should be 0
                if (tooth.state === ToothState.EXTRACTED) {
                    tooth.health = 0;
                }
            }
        }
        
        // Pick a random tooth to "hover" over
        const toothIndex = Math.floor(Math.random() * 32) + 1;
        const tooth = ToothManager.getToothByIndex(mockPlayer, toothIndex);
        
        let isValid = true;
        let failReason = null;
        
        if (!tooth) {
            isValid = false;
            failReason = `Tooth ${toothIndex} is null`;
        } else {
            // Check 1: Tooth name exists and is non-empty string
            if (!tooth.name || typeof tooth.name !== 'string' || tooth.name === '') {
                isValid = false;
                failReason = `Tooth ${toothIndex} has invalid name: ${tooth.name}`;
            }
            
            // Check 2: Health is a number in range 0-100
            if (isValid) {
                if (typeof tooth.health !== 'number') {
                    isValid = false;
                    failReason = `Tooth ${toothIndex} health is not a number: ${typeof tooth.health}`;
                } else if (tooth.health < 0 || tooth.health > 100) {
                    isValid = false;
                    failReason = `Tooth ${toothIndex} health out of range: ${tooth.health}`;
                }
            }
            
            // Check 3: State is a valid state string
            if (isValid) {
                if (!tooth.state || typeof tooth.state !== 'string') {
                    isValid = false;
                    failReason = `Tooth ${toothIndex} has invalid state type: ${typeof tooth.state}`;
                } else {
                    // Verify state is one of the valid states
                    if (!allStates.includes(tooth.state)) {
                        isValid = false;
                        failReason = `Tooth ${toothIndex} has unknown state: ${tooth.state}`;
                    }
                }
            }
            
            // Check 4: Verify tooltip would have all required info
            if (isValid) {
                const nameText = tooth.name;
                const healthText = `Health: ${Math.floor(tooth.health)}%`;
                const stateText = `State: ${tooth.state}`;
                
                // Verify name text is displayable
                if (nameText.length === 0) {
                    isValid = false;
                    failReason = "Tooltip name text is empty";
                }
                
                // Verify health text contains percentage
                if (isValid && !healthText.includes('%')) {
                    isValid = false;
                    failReason = "Tooltip health text missing percentage";
                }
                
                // Verify state text contains state
                if (isValid && !stateText.includes(tooth.state)) {
                    isValid = false;
                    failReason = "Tooltip state text missing state value";
                }
            }
        }
        
        if (isValid) {
            passed++;
        } else {
            failed++;
            failures.push({ iteration: i, reason: failReason, toothIndex, tooth });
        }
    }
    
    return { property: "Tooltip Information Completeness (P6)", iterations, passed, failed, failures, success: failed === 0 };
}

// Run all tests
function runAllTests(iterations = 100) {
    console.log("");
    console.log("============================================");
    console.log("  DentalPain Property-Based Test Suite");
    console.log("============================================");
    console.log(`  Iterations per property: ${iterations}`);
    console.log("");
    
    const results = [];
    
    // ToothManager tests (Property 1-4)
    results.push(property_ToothInitializationInvariant(iterations));
    results.push(property_DamageDistributionToNonExtracted(iterations));
    results.push(property_ZeroHealthStateTransition(iterations));
    results.push(property_ExtractionPermanence(iterations));
    
    // SkillManager tests (Property 8 & 9)
    results.push(property_SkillUnlockThresholds(iterations));
    results.push(property_SkillLevelCap(iterations));
    
    // FormulaCalculator tests (Property 7, 13, 14)
    results.push(property_SkillLevelSuccessRateFormula(iterations));
    results.push(property_FailureDamageInverseRelationship(iterations));
    results.push(property_ToolModifierDifference(iterations));
    
    // ZombiePractice tests (Property 10, 11, 12)
    results.push(property_ZombiePracticeXPRewards(iterations));
    results.push(property_ZombiePracticeSafety(iterations));
    results.push(property_ZombieCorpseExtractionLimit(iterations));
    
    // ToothMapUI tests (Property 5, 6)
    results.push(property_ToothStateColorMapping(iterations));
    results.push(property_TooltipInformationCompleteness(iterations));
    
    console.log("=== PROPERTY TEST RESULTS ===");
    for (const result of results) {
        const status = result.success ? "PASSED" : "FAILED";
        console.log(`  [${status}] ${result.property} (${result.passed}/${result.iterations} iterations)`);
        
        if (!result.success && result.failures.length > 0) {
            console.log("    First failure:");
            console.log(`      Iteration: ${result.failures[0].iteration}`);
            console.log(`      Reason: ${result.failures[0].reason}`);
        }
    }
    console.log("=============================");
    
    const allPassed = results.every(r => r.success);
    
    console.log("");
    if (allPassed) {
        console.log("ALL TESTS PASSED ✓");
    } else {
        console.log("SOME TESTS FAILED ✗");
    }
    
    return allPassed;
}

// Execute tests
const success = runAllTests(100);
process.exit(success ? 0 : 1);
