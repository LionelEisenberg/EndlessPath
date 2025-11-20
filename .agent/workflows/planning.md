---
description: Comprehensive planning workflow for new features or complex changes
---

1. **Codebase Analysis**
   - Read through the codebase and identify key stylistic and architectural procedures that are in place to keep a clean and legible codebase (e.g., comment style in classes, data structure flows, file naming schemes, etc.).

2. **Prompt Analysis**
   - Read the question / system you are trying to plan.
   - First and foremost, identify any issues you might have with the initial prompt.
   - **Game Design Analysis**: Analyze the planning phase and prompt specifically through a game design lens. Does it make sense for the player? Is it fun? Does it fit the game's loop?
   - Check for any clarity problems in the prompt.
   - Read through the prompt and check for anything between brackets `[...]`; these are direct instructions to you.

3. **Clarification**
   - Before planning, ask input and questions to the user for them to clarify anything that seems off or ambiguous.

4. **Develop Structured Plan**
   - Come up with a structured plan which will have the following structure:
     1. **Introduction**: What is trying to be planned.
     2. **Logic Flow**: High-level logic flow.
     3. **New Logic Systems / APIs**: Low-code, conceptual class responsibilities. **Include specific function definitions and their responsibilities.**
     4. **New Data Structures**: Low-code data definitions.
     5. **Per-file Changes**: Specific changes required per file.
     6. **Potential Next Steps / Improvements**: Suggest how to improve things or what to work on next.

5. **Constraint: No Implementation**
   - **DO NOT UNDER ANY CIRCUMSTANCE ACTUALLY IMPLEMENT THE IMPLEMENTATION PLAN** at this stage.

6. **Implementation Strategy (Post-Approval)**
   - **Update Planning Doc**: Always update the planning document as you implement changes.
   - When you do implement (after plan approval), implement file by file starting with the lowest level structure.
   - **Approve review** before moving to the next file.
   - **Post-Implementation Review**: Once a plan is considered implemented:
     - Update the doc to say it is implemented.
     - Run a code check to see if the actual implementation differed from the design.
     - Update the original planning document to reflect the final reality of the code.
