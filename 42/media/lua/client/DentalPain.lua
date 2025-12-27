-- DentalPain entry point
-- Modularized for B42.13 compatibility

require "DentalPain/Core"
require "DentalPain/Dialogue"
require "DentalPain/Hygiene"
require "DentalPain/Medical"
require "DentalPain/Events"
require "DentalPain/ToothManager"
require "DentalPain/SkillManager"
require "DentalPain/FormulaCalculator"
require "DentalPain/ZombiePractice"

-- Require UI modules
require "DentalPain/UI/ToothMapUI"

-- Require Timed Actions
require "TimedActions/ISDentalAction"
require "TimedActions/ISExtractionAction"
require "TimedActions/ISZombiePracticeAction"

DentalPain.debug("DentalPain Mod: Modular System Initialized.")


