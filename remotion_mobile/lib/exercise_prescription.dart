class ExercisePrescription {
  final String exerciseId;
  final String exerciseName;
  final int targetReps;
  final int targetSets;
  final int holdSeconds;

  const ExercisePrescription({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetReps,
    required this.targetSets,
    required this.holdSeconds,
  });
}
