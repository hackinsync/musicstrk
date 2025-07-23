
# Audition Evaluation Framework Design

This document outlines the step-by-step plan to implement a robust, fair, and extensible evaluation system for auditions. The goal is to enable detailed, weighted, and transparent scoring by judges, support appeals, analytics, and provide a foundation for participant improvement.

---

## 1. Evaluation Struct Design
- **Define an `Evaluation` struct** capturing:
  - `technical_skills_score: u8`
  - `creativity_score: u8`
  - `presentation_score: u8`
  - `feedback: felt252` (or string/bytes, for judge comments)
  - `judge: ContractAddress`
  - `audition_id: felt252`
  - `performer_id: felt252`
  - `timestamp: felt252`
- **Extendable**: Allow for additional criteria in the future.

## 2. Judge Authorization
- **Add judge management**:
  - Functions to add/remove judges (by owner or session creator)
  - Storage mapping: `judges: Map<ContractAddress, bool>`
  - Only authorized judges can submit evaluations.

## 3. Evaluation Submission
- **Function for judges to submit evaluations**:
  - Accepts all fields in the `Evaluation` struct
  - Checks:
    - Judge is authorized
    - Audition is open for evaluation
    - One evaluation per judge per performer per audition
  - Emits `EvaluationSubmitted` event

## 4. Weighted Scoring System
- **Define weights per criterion**:
  - Storage: `evaluation_weights: (u8, u8, u8)` (technical, creativity, presentation)
  - Allow session creator to set weights per audition/season
  - Final score = weighted sum of criteria

## 5. Ranking Algorithm
- **Aggregate all evaluations for each performer in an audition**
- Compute average weighted score per performer
- Sort performers by final score (descending)
- Expose a function to get ranked list for an audition

## 6. Evaluation Deadlines
- **Add evaluation period to auditions**:
  - `evaluation_start_timestamp`, `evaluation_end_timestamp`
  - Only allow submissions within this window
  - After deadline, scoring is closed automatically

## 7. Appeal Process
- **Allow performers to appeal evaluations**:
  - Function to submit an appeal (with reason/comment)
  - Storage for appeals, linked to evaluation
  - Judges/owner can review and resolve appeals
  - Events for appeal submitted/resolved

## 8. Aggregate Scoring
- **Combine multiple judge evaluations per performer**:
  - Use average or median of all judge scores
  - Expose aggregate score per performer per audition

## 9. Evaluation Analytics
- **Provide analytics functions**:
  - Average scores per criterion
  - Score distribution (min, max, mean, stddev)
  - Judge consistency (variance in scoring)
  - Expose analytics for session creators

## 10. Evaluation Templates
- **Allow customizable templates per session/audition**:
  - Define which criteria are used and their weights
  - Store template per audition/season
  - Judges see the correct template when submitting

## 11. Evaluation History Tracking
- **Track all evaluations for each performer over time**:
  - Storage mapping: performer_id → list of evaluations
  - Expose history for improvement tracking

---

## Implementation Steps

1. **Design Data Structures**
   - Evaluation struct, weights, templates, appeals, analytics storage
2. **Judge Management**
   - Add/remove judge functions, access control
3. **Evaluation Submission**
   - Submission, validation, event emission
4. **Weighted Scoring & Aggregation**
   - Weight storage, score calculation, aggregation logic
5. **Ranking & Analytics**
   - Ranking function, analytics endpoints
6. **Deadlines & State Management**
   - Evaluation period enforcement
7. **Appeal System**
   - Appeal submission, review, resolution
8. **Templates & Customization**
   - Template creation, assignment, enforcement
9. **History Tracking**
   - Store and expose evaluation history
10. **Testing & Documentation**
   - Unit tests, integration tests, user documentation

---

## Notes
- All functions should be access-controlled (owner/s