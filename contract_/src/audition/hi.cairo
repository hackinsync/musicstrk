// let (technical_weight, creativity_weight, presentation_weight) =
// self.get_evaluation_weight(audition_id);
// assert(technical_weight == WEIGHT_TECHNICAL && creativity_weight == WEIGHT_CREATIVITY &&
// presentation_weight == WEIGHT_PRESENTATION, 'Invalid weights');

// let all_performers: Array<felt252> = self.get_enrolled_performers(audition_id);

// for performer in all_performers {
//     let all_evaluations_for_performer: Array<Evaluation> = self.get_evaluation(audition_id,
//     *performer);
//     assert(all_evaluations_for_performer.len() > 0, 'No evaluations for performer');

//     let mut total_score: u32 = 0;
//     let num_judges: u32 = all_evaluations_for_performer.len();

//     for evaluation in all_evaluations_for_performer {
//         let (technical_score, creativity_score, presentation_score) = evaluation.criteria;
//         assert(technical_score >= 1 && technical_score <= 10, 'Invalid technical score');
//         assert(creativity_score >= 1 && creativity_score <= 10, 'Invalid creativity score');
//         assert(presentation_score >= 1 && presentation_score <= 10, 'Invalid presentation
//         score');

//         let weighted_score: u32 = (technical_score * technical_weight
//             + creativity_score * creativity_weight
//             + presentation_score * presentation_weight) / PRECISION;
//         total_score += weighted_score;
//     }

//     let average_final_score: u32 = total_score / num_judges;
//     self.aggregate_scores.write((audition_id, *performer), average_final_score);
//     self.emit(Event::ScoreCalculated(ScoreCalculated { audition_id, performer: *performer, score:
//     average_final_score }));
// }
