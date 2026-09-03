class ErrorMapper {
  /// Maps a raw exception or error to a user-friendly message.
  static String mapErrorToUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('invalid or insufficient shares')) {
      return 'Your wallet backup shares are missing or corrupted on this device. Please completely uninstall the app, reinstall it, and restore your wallet using your backup shares.';
    }
    
    if (errorString.contains('incorrect passphrase')) {
      return 'The passphrase you entered is incorrect. Please try again.';
    }

    if (errorString.contains('rpc endpoints disagree')) {
      return 'We could not reliably verify the status of this transaction on the network right now. Please wait a moment and check your history.';
    }

    if (errorString.contains('network') || errorString.contains('socketexception') || errorString.contains('connection')) {
      return 'It looks like you have a poor internet connection. Please check your network and try again.';
    }

    if (errorString.contains('insufficient funds') || errorString.contains('balance too low')) {
      return 'You do not have enough funds to complete this transaction. Remember that you also need enough native currency to pay for network fees.';
    }

    // Default fallback
    return 'Something went wrong: ${error.toString()}';
  }
}
