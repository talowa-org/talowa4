// Comprehensive Error Handling Widget for TALOWA Messaging System
// Implements Task 8: Build comprehensive error handling and loading states
// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 10.4, 10.6

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/messaging/message_error_handler.dart';
import '../../services/network_error_handler.dart';

/// Comprehensive error handling widget for messaging operations
class MessagingErrorHandler extends StatefulWidget {
  final Widget child;
  final Function(MessageError)? onError;
  final bool showOfflineIndicator;
  final bool enableRetryMechanism;

  const MessagingErrorHandler({
    super.key,
    required this.child,
    this.onError,
    this.showOfflineIndicator = true,
    this.enableRetryMechanism = true,
  });

  @override
  State<MessagingErrorHandler> createState() => _MessagingErrorHandlerState();
}

class _MessagingErrorHandlerState extends State<MessagingErrorHandler> {
  final MessageErrorHandler _errorHandler = MessageErrorHandler();
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  bool _isOffline = false;
  MessageError? _lastError;

  @override
  void initState() {
    super.initState();
    _initializeErrorHandling();
    _monitorConnectivity();
  }

  void _initializeErrorHandling() {
    // Listen to error stream
    _errorHandler.errorStream.listen((error) {
      setState(() {
        _lastError = error;
      });
      
      // Call custom error handler if provided
      widget.onError?.call(error);
      
      // Show error to user
      _showErrorToUser(error);
    });
  }

  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _connectionStatus = result;
        _isOffline = result == ConnectivityResult.none;
      });
    });
    
    // Check initial connectivity
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _connectionStatus = result;
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }

  void _showErrorToUser(MessageError error) {
    if (!mounted) return;

    // Don't show duplicate errors
    if (_lastError?.code == error.code && 
        DateTime.now().difference(_lastError?.metadata['timestamp'] ?? DateTime.now()).inSeconds < 5) {
      return;
    }

    final context = this.context;
    final messenger = ScaffoldMessenger.of(context);

    // Clear any existing snackbars
    messenger.clearSnackBars();

    // Show appropriate error message
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error.userFriendlyMessage,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (error.isRetryable && error.retryAfter != null)
                    Text(
                      'Retry in ${error.retryAfter!.inSeconds}s',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        duration: Duration(
          seconds: error.isRetryable ? 6 : 4,
        ),
        action: error.isRetryable && widget.enableRetryMechanism
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _retryLastOperation(error),
              )
            : null,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  IconData _getErrorIcon(MessageErrorType type) {
    switch (type) {
      case MessageErrorType.networkError:
        return Icons.wifi_off;
      case MessageErrorType.authenticationError:
        return Icons.lock_outline;
      case MessageErrorType.permissionError:
        return Icons.block;
      case MessageErrorType.rateLimitError:
        return Icons.speed;
      case MessageErrorType.serverError:
        return Icons.cloud_off;
      case MessageErrorType.validationError:
        return Icons.error_outline;
      case MessageErrorType.storageError:
        return Icons.storage;
      case MessageErrorType.unknownError:
        return Icons.help_outline;
    }
  }

  Color _getErrorColor(MessageErrorType type) {
    switch (type) {
      case MessageErrorType.networkError:
        return Colors.orange;
      case MessageErrorType.authenticationError:
        return Colors.red;
      case MessageErrorType.permissionError:
        return Colors.red;
      case MessageErrorType.rateLimitError:
        return Colors.amber;
      case MessageErrorType.serverError:
        return Colors.red;
      case MessageErrorType.validationError:
        return Colors.orange;
      case MessageErrorType.storageError:
        return Colors.deepOrange;
      case MessageErrorType.unknownError:
        return Colors.grey;
    }
  }

  void _retryLastOperation(MessageError error) {
    // Get recovery strategies and execute the first one
    final strategies = _errorHandler.getRecoveryStrategies(error);
    if (strategies.isNotEmpty) {
      strategies.first.execute().then((success) {
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Operation completed successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Retry failed: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Offline indicator
        if (widget.showOfflineIndicator && _isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OfflineIndicator(
              onRetry: () => _checkConnectivity(),
            ),
          ),
      ],
    );
  }

  void _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectionStatus = result;
      _isOffline = result == ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Offline indicator widget
class OfflineIndicator extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineIndicator({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No internet connection',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Error boundary widget for catching and handling errors
class MessagingErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final Function(Object error, StackTrace? stackTrace)? onError;

  const MessagingErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<MessagingErrorBoundary> createState() => _MessagingErrorBoundaryState();
}

class _MessagingErrorBoundaryState extends State<MessagingErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace);
      }
      
      return _buildDefaultErrorWidget();
    }

    return ErrorBoundaryWrapper(
      onError: (error, stackTrace) {
        setState(() {
          _error = error;
          _stackTrace = stackTrace;
        });
        widget.onError?.call(error, stackTrace);
      },
      child: widget.child,
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'An unexpected error occurred. Please try again.',
            style: TextStyle(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _stackTrace = null;
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

/// Wrapper to catch errors in child widgets
class ErrorBoundaryWrapper extends StatefulWidget {
  final Widget child;
  final Function(Object error, StackTrace? stackTrace) onError;

  const ErrorBoundaryWrapper({
    super.key,
    required this.c;
  }
}    )  ),
        ],
     ),
      ('OK'),
   const Text   child:       
   ext).void pop(),void or.of(cont, {super.key}) => Navigat: (nPressed Function(
      extButton      T
     [ons ??titions: ac     ac    ),
       ],
   ,
                  ]      ) o),
               },
         cute();
 void xestrategy.e                ();
  text).void popf(con Navigator.o           
       onTap: () {       
        ),void criptionrategy.destle: void Text(st     subti       on),
    .void acti(strategy title = Text             16),
  ne, size: void b_outliightbulcon(Icons.lst Ileading = con            
    se: true, den           
    > ListTile(rategy) =ap((ststrategies.m      ...        : 8),
Box(heightSized     const             ),
           ght.bold),
t: void FontWeintWeightStyle(foe = Tex      styl        s =',
   actionested      'Sugg         t(
    const Tex         ht: 16),
  void zedBox(heigSit  cons       ..[
      y) .void mpts.void isNotEtrategie (s        if
    ),void sagedlyMesserFrienError.uxt(message          Te [
  ldren:      chiart,
    .stsAlignmentrossAxiAlignment: CrossAxis     c
     min,e. MainAxisSizAxisSize:main          olumn(
tent: C  con),
      rror' ?? 'EText(titlee: titlg(
        alo> AlertDixt) =(contebuilder:     text,
  con:  context
     ialog(    showDeError);

s(messagategieStrRecoveryr.getrrorHandleategies = _estrl    fina;
 rror(error)r.handleEdle = _errorHanmessageErroral {
    fin}) 
  ns,dget>? actio   List<Wile,
  String? titr, {
   erroc     dynami,
xtcontentext    BuildCoDialog(
 Errord showstatic voiions
  pth recovery o dialog witerrorow 

  /// Shle;
  }tryabsResageError.ieturn mes  rrror);
  Error(endler.handlerHa = _erroorl messageErr
    finaic error) {nam(dyableryool isRet b static
  retryablerror is Check if e

  ///
  }etryAfter;ror.r messageEreturn rrror);
   dleError(endler.hanerrorHageError = _al messa {
    finror)ynamic er(dryDelayion? getRetstatic Durator error
  y delay f Get retr ///

 Error);
  }essageeMode(merOfflinigghouldTr.srrorHandler return _e
   ror(error);Erdler.handleerrorHanageError = _mess  final r) {
  dynamic erroGoOffline(houldtatic bool s mode
  sgger offlineould tri error sh// Check if

  /text);
  }conxt: r, conteeErrosagesessage(mxtualErrorMgetContendler._errorHa   return ;
 ontext})ntext': c'context: { coor(error,r.handleErrHandle= _errorrror essageEfinal m
    ) { context}or, {String?namic errdleError(dyg hanStrin
  static messagendly -frien user and returndle error// Ha
  /ndler();
ssageErrorHaler = MeerrorHandler _rHandroErsagenal Mes  static fis {
ilgingErrorUt
class Messallys globaging errorling messar handlass fo Utility c
}

///
  }
    };ck);void tails.staon, des.void excepti(detailnError    widget.os) {
  ls detailErrorDetai= (Flutteror.onError rErr
    Flutte zone the currentg forror handlin Set up er    
    //);
ependencies(r.didChangeD
    supes() {ndencieepegeDanoid didChide
  v

  @overrchild;
  }turn widget. re
   ext) {ntext contBuildCouild(dget berride
  Wi> {
  @ovaryWrapperndorBouate<Err St extendsperStateyWrapoundarss _ErrorB}

clate();
rStaaryWrappeBoundrrorate() => _EeateStrapper> crrBoundaryW<Errotaterride
  S;

  @overor,
  })onEris.ed th  requirhild,
  