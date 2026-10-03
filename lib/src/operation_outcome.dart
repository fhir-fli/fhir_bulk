/// One error issue in an OperationOutcome, as JSON: the shape every package
/// in this family answers a failure with (the typed `errorOperationOutcome`
/// that fhir_generator emits into each fhir_r* package builds the same
/// resource).
///
/// Severity is `error`. [code] defaults to `invalid`, the IssueType for
/// content or a request that could not be processed; [details] is the text
/// a person reads, [diagnostics] what the machine knows (a response body, an
/// exception message).
Map<String, dynamic> errorOperationOutcomeJson({
  String? details,
  String? diagnostics,
  String code = 'invalid',
}) => {
  'resourceType': 'OperationOutcome',
  'issue': [
    {
      'severity': 'error',
      'code': code,
      if (details != null) 'details': {'text': details},
      if (diagnostics != null) 'diagnostics': diagnostics,
    },
  ],
};
