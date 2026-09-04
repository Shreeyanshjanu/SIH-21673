enum OperationMode { walkieTalkie, continuous }

String operationModeToWire(OperationMode mode) {
  switch (mode) {
    case OperationMode.walkieTalkie:
      return 'walkie_talkie';
    case OperationMode.continuous:
      return 'continuous';
  }
}
