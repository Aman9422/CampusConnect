Launching lib\main.dart on sdk gphone16k x86 64 in debug mode...
√ Built build\app\outputs\flutter-apk\app-debug.apk
D/FlutterJNI( 5227): Beginning load of flutter...
D/FlutterJNI( 5227): flutter (null) was loaded normally!
I/flutter ( 5227): [IMPORTANT:flutter/shell/platform/android/android_context_gl_impeller.cc(104)] Using the Impeller rendering backend (OpenGLES).
W/t.campusconnect( 5227): ClassLoaderContext classpath size mismatch. expected=1, found=0 (DLC[];PCL[base.apk*261935768]{PCL[/system/framework/org.apache.http.legacy.jar*4247870504]#PCL[/system/framework/com.android.location.provider.jar*1570284764]#PCL[/system/framework/com.android.media.remotedisplay.jar*487574312]#PCL[/system_ext/framework/com.android.extensions.appfunctions.jar*2880224042]#PCL[/system_ext/framework/androidx.window.extensions.jar*1030441313]#PCL[/system_ext/framework/androidx.window.sidecar.jar*3860983653]} | DLC[];PCL[])
I/DynamiteModule( 5227): Considering local module com.google.android.gms.measurement.dynamite:155 and remote module com.google.android.gms.measurement.dynamite:199
I/DynamiteModule( 5227): Selected remote version of com.google.android.gms.measurement.dynamite, version >= 199
V/DynamiteModule( 5227): Dynamite loader version >= 2, using loadModule2NoCrashUtils
W/System  ( 5227): ClassLoader referenced unknown path:
D/nativeloader( 5227): Configuring clns-10 for other apk . target_sdk_version=37, uses_libraries=, library_path=/data/app/~~gFiDFXQXZ0v7dkjp4Dcc8w==/com.google.android.gms-23rUIMQNlbIXAgjU0qGf4Q==/lib/x86_64:/data/app/~~gFiDFXQXZ0v7dkjp4Dcc8w==/com.google.android.gms-23rUIMQNlbIXAgjU0qGf4Q==/base.apk!/lib/x86_64, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
I/t.campusconnect( 5227): AssetManager2(0x7c7074ce7278) locale list changing from [] to [en-US]
W/t.campusconnect( 5227): ClassLoaderContext classpath element checksum mismatch. expected=261935768, found=2608611123 (DLC[];PCL[base.apk*261935768]{PCL[/system/framework/org.apache.http.legacy.jar*4247870504]#PCL[/system/framework/com.android.location.provider.jar*1570284764]#PCL[/system/framework/com.android.media.remotedisplay.jar*487574312]#PCL[/system_ext/framework/com.android.extensions.appfunctions.jar*2880224042]#PCL[/system_ext/framework/androidx.window.extensions.jar*1030441313]#PCL[/system_ext/framework/androidx.window.sidecar.jar*3860983653]} | DLC[];PCL[/data/app/~~aKi76UvpDTL4uiR-E_J3Tw==/io.campusconnect.campusconnect-Ak9N5cS-wJhZpG0LVtTPLA==/base.apk*2608611123]{PCL[/system_ext/framework/androidx.window.extensions.jar*1030441313]#PCL[/system_ext/framework/androidx.window.sidecar.jar*3860983653]})
I/t.campusconnect( 5227): AssetManager2(0x7c7074ce30d8) locale list changing from [] to [en-US]
I/t.campusconnect( 5227): AssetManager2(0x7c7074ce5658) locale list changing from [] to [en-US]
Connecting to VM Service at ws://127.0.0.1:56633/8ZZ5LZs5we4=/ws
Connected to the VM Service.
E/IPCThreadState( 5227): Binder transaction failure. id: 2237294, BR_*: 29201, error: -28 (No space left on device)
E/JavaBinder( 5227): !!! FAILED BINDER TRANSACTION !!!  (parcel size = 1404)
W/GmsClient( 5227): IGmsServiceBroker.getService failed
W/GmsClient( 5227): android.os.DeadObjectException: Transaction failed on small parcel; remote process probably died, but this could also be caused by running out of binder buffer space
W/GmsClient( 5227): 	at android.os.BinderProxy.transactNative(Native Method)
W/GmsClient( 5227): 	at android.os.BinderProxy.transact(BinderProxy.java:592)
W/GmsClient( 5227): 	at m7.fw.m(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):180)
W/GmsClient( 5227): 	at m7.ep.run(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):42)
W/GmsClient( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/GmsClient( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/GmsClient( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/GmsClient( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/GmsClient( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
I/t.campusconnect( 5227): hiddenapi: Accessing hidden method Ldalvik/system/VMStack;->getStackClass2()Ljava/lang/Class; (runtime_flags=0, domain=core-platform, api=unsupported) from Lm7/apz; (domain=app) using reflection: allowed
I/PhClient( 5227): Shared storage file not found for com.google.android.gms.measurement#io.campusconnect.campusconnect
E/t.campusconnect( 5227): No package ID 6a found for resource ID 0x6a0b0013.
E/IPCThreadState( 5227): Binder transaction failure. id: 2237528, BR_*: 29201, error: -28 (No space left on device)
D/ActivityThread( 5227): Too many transaction errors, throttling freezer binder callback.
E/JavaBinder( 5227): !!! FAILED BINDER TRANSACTION !!!  (parcel size = 1404)
W/GmsClient( 5227): IGmsServiceBroker.getService failed
W/GmsClient( 5227): android.os.DeadObjectException: Transaction failed on small parcel; remote process probably died, but this could also be caused by running out of binder buffer space
W/GmsClient( 5227): 	at android.os.BinderProxy.transactNative(Native Method)
W/GmsClient( 5227): 	at android.os.BinderProxy.transact(BinderProxy.java:592)
W/GmsClient( 5227): 	at m7.fw.m(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):180)
W/GmsClient( 5227): 	at m7.ep.run(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):42)
W/GmsClient( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/GmsClient( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/GmsClient( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/GmsClient( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/GmsClient( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
I/FA      ( 5227): App measurement initialized, version: 175000
I/FA      ( 5227): To enable debug logging run: adb shell setprop log.tag.FA VERBOSE
I/FA      ( 5227): To enable faster debug mode event logging run:
I/FA      ( 5227):   adb shell setprop debug.firebase.analytics.app io.campusconnect.campusconnect
I/FA      ( 5227): Tag Manager is not found and thus will not be used
I/t.campusconnect( 5227): Compiler allocated 5057KB to compile void android.view.ViewRootImpl.performTraversals()
I/Choreographer( 5227): Skipped 230 frames!  The application may be doing too much work on its main thread.
D/WindowLayoutComponentImpl( 5227): Register WindowLayoutInfoListener on Context=io.campusconnect.campusconnect.MainActivity@6596eb7, of which baseContext=android.app.ContextImpl@d1d9775
D/ProfileInstaller( 5227): Installing profile for io.campusconnect.campusconnect
E/IPCThreadState( 5227): Binder transaction failure. id: 2244137, BR_*: 29201, error: -28 (No space left on device)
D/ActivityThread( 5227): Too many transaction errors, throttling freezer binder callback.
E/JavaBinder( 5227): !!! FAILED BINDER TRANSACTION !!!  (parcel size = 1404)
W/GmsClient( 5227): IGmsServiceBroker.getService failed
W/GmsClient( 5227): android.os.DeadObjectException: Transaction failed on small parcel; remote process probably died, but this could also be caused by running out of binder buffer space
W/GmsClient( 5227): 	at android.os.BinderProxy.transactNative(Native Method)
W/GmsClient( 5227): 	at android.os.BinderProxy.transact(BinderProxy.java:592)
W/GmsClient( 5227): 	at m7.fw.m(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):180)
W/GmsClient( 5227): 	at m7.ep.run(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):42)
W/GmsClient( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/GmsClient( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/GmsClient( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/GmsClient( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/GmsClient( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
E/IPCThreadState( 5227): Binder transaction failure. id: 2244757, BR_*: 29201, error: -28 (No space left on device)
D/ActivityThread( 5227): Too many transaction errors, throttling freezer binder callback.
E/JavaBinder( 5227): !!! FAILED BINDER TRANSACTION !!!  (parcel size = 1404)
W/GmsClient( 5227): IGmsServiceBroker.getService failed
W/GmsClient( 5227): android.os.DeadObjectException: Transaction failed on small parcel; remote process probably died, but this could also be caused by running out of binder buffer space
W/GmsClient( 5227): 	at android.os.BinderProxy.transactNative(Native Method)
W/GmsClient( 5227): 	at android.os.BinderProxy.transact(BinderProxy.java:592)
W/GmsClient( 5227): 	at m7.fw.m(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):180)
W/GmsClient( 5227): 	at m7.ep.run(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):42)
W/GmsClient( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/GmsClient( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/GmsClient( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/GmsClient( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/GmsClient( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
E/IPCThreadState( 5227): Binder transaction failure. id: 2245908, BR_*: 29201, error: -28 (No space left on device)
D/ActivityThread( 5227): Too many transaction errors, throttling freezer binder callback.
E/JavaBinder( 5227): !!! FAILED BINDER TRANSACTION !!!  (parcel size = 716)
W/GmsClient( 5227): IGmsServiceBroker.getService failed
W/GmsClient( 5227): android.os.DeadObjectException: Transaction failed on small parcel; remote process probably died, but this could also be caused by running out of binder buffer space
W/GmsClient( 5227): 	at android.os.BinderProxy.transactNative(Native Method)
W/GmsClient( 5227): 	at android.os.BinderProxy.transact(BinderProxy.java:592)
W/GmsClient( 5227): 	at m7.fw.m(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):180)
W/GmsClient( 5227): 	at m7.ep.run(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):42)
W/GmsClient( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/GmsClient( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/GmsClient( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/GmsClient( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/GmsClient( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
E/IPCThreadState( 5227): Binder transaction failure. id: 2248559, BR_*: 29201, error: -28 (No space left on device)
E/JavaBinder( 5227): !!! FAILED BINDER TRANSACTION !!!  (parcel size = 1404)
W/GmsClient( 5227): IGmsServiceBroker.getService failed
W/GmsClient( 5227): android.os.DeadObjectException: Transaction failed on small parcel; remote process probably died, but this could also be caused by running out of binder buffer space
W/GmsClient( 5227): 	at android.os.BinderProxy.transactNative(Native Method)
W/GmsClient( 5227): 	at android.os.BinderProxy.transact(BinderProxy.java:592)
W/GmsClient( 5227): 	at m7.fw.m(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):180)
W/GmsClient( 5227): 	at m7.ep.run(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):42)
W/GmsClient( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/GmsClient( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/GmsClient( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/GmsClient( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/GmsClient( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
I/Choreographer( 5227): Skipped 35 frames!  The application may be doing too much work on its main thread.
E/IPCThreadState( 5227): Binder transaction failure. id: 2248726, BR_*: 29201, error: -28 (No space left on device)
D/ActivityThread( 5227): Too many transaction errors, throttling freezer binder callback.
E/JavaBinder( 5227): !!! FAILED BINDER TRANSACTION !!!  (parcel size = 1404)
W/GmsClient( 5227): IGmsServiceBroker.getService failed
W/GmsClient( 5227): android.os.DeadObjectException: Transaction failed on small parcel; remote process probably died, but this could also be caused by running out of binder buffer space
W/GmsClient( 5227): 	at android.os.BinderProxy.transactNative(Native Method)
W/GmsClient( 5227): 	at android.os.BinderProxy.transact(BinderProxy.java:592)
W/GmsClient( 5227): 	at m7.fw.m(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):180)
W/GmsClient( 5227): 	at m7.ep.run(:com.google.android.gms.dynamite_measurementdynamite@262634038@26.26.34 (260800-0):42)
W/GmsClient( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/GmsClient( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/GmsClient( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/GmsClient( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/GmsClient( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
I/Choreographer( 5227): Skipped 69 frames!  The application may be doing too much work on its main thread.
I/Choreographer( 5227): Skipped 82 frames!  The application may be doing too much work on its main thread.
I/t.campusconnect( 5227): NativeAlloc concurrent copying GC freed 3170KB AllocSpace bytes, 16(624KB) LOS objects, 49% free, 3673KB/7346KB, paused 915us,19us total 119.819ms
I/t.campusconnect( 5227): AssetManager2(0x7c7074cf46f8) locale list changing from [] to [en-US]
D/InsetsController( 5227): hide(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:e420275e: onCancelled at PHASE_CLIENT_ALREADY_HIDDEN
I/ImeTracker( 5227): io.campusconnect.campusconnect:bdf05ca0: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
I/AssistStructure( 5227): Flattened final assist data: 512 bytes, containing 1 windows, 3 views
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
W/InteractionJankMonitor( 5227): Initializing without READ_DEVICE_CONFIG permission. enabled=false, interval=1, missedFrameThreshold=3, frameTimeThreshold=64, package=io.campusconnect.campusconnect
I/ImeTracker( 5227): system_server:6cd7b207: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:1b66f2a7: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
D/CompatChangeReporter( 5227): Compat change id reported: 395521150; UID 10237; state: ENABLED
I/ImeTracker( 5227): system_server:b63ea519: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
I/ImeTracker( 5227): io.campusconnect.campusconnect:a8159ae7: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/AssistStructure( 5227): Flattened final assist data: 504 bytes, containing 1 windows, 3 views
I/ImeTracker( 5227): io.campusconnect.campusconnect:a8159ae7: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:1d5e7b1a: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:1d5e7b1a: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/AssistStructure( 5227): Flattened final assist data: 512 bytes, containing 1 windows, 3 views
I/ImeTracker( 5227): io.campusconnect.campusconnect:ce8ee530: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:ce8ee530: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/AssistStructure( 5227): Flattened final assist data: 504 bytes, containing 1 windows, 3 views
I/ImeTracker( 5227): io.campusconnect.campusconnect:d73fa0e0: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:d73fa0e0: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/AssistStructure( 5227): Flattened final assist data: 520 bytes, containing 1 windows, 3 views
I/FirebaseAuth( 5227): Creating user with ajayak@jdcoem.ac.in with empty reCAPTCHA token
W/System  ( 5227): Ignoring header X-Firebase-Locale because its value was null.
W/LocalRequestInterceptor( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
W/System  ( 5227): Ignoring header X-Firebase-Locale because its value was null.
W/LocalRequestInterceptor( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
D/FirebaseAuth( 5227): Notifying id token listeners about user ( ynleASY3m0dJ0dVkQ6D9K1xMVKv2 ).
D/FirebaseAuth( 5227): Notifying auth state listeners about user ( ynleASY3m0dJ0dVkQ6D9K1xMVKv2 ).
W/DynamiteModule( 5227): Local module descriptor class for com.google.android.gms.providerinstaller.dynamite not found.
I/DynamiteModule( 5227): Considering local module com.google.android.gms.providerinstaller.dynamite:0 and remote module com.google.android.gms.providerinstaller.dynamite:0
W/ProviderInstaller( 5227): Failed to load providerinstaller module: No acceptable module com.google.android.gms.providerinstaller.dynamite found. Local version is 0 and remote version is 0.
D/ApplicationLoaders( 5227): Returning zygote-cached class loader: /system/framework/org.apache.http.legacy.jar
D/ApplicationLoaders( 5227): Returning zygote-cached class loader: /system/framework/com.android.location.provider.jar
D/ApplicationLoaders( 5227): Returning zygote-cached class loader: /system/framework/com.android.media.remotedisplay.jar
D/nativeloader( 5227): Configuring clns-11 for other apk /system_ext/framework/com.android.extensions.appfunctions.jar. target_sdk_version=37, uses_libraries=ALL, library_path=/data/app/~~gFiDFXQXZ0v7dkjp4Dcc8w==/com.google.android.gms-23rUIMQNlbIXAgjU0qGf4Q==/lib/x86_64:/data/app/~~gFiDFXQXZ0v7dkjp4Dcc8w==/com.google.android.gms-23rUIMQNlbIXAgjU0qGf4Q==/base.apk!/lib/x86_64, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
D/ApplicationLoaders( 5227): Returning zygote-cached class loader: /system_ext/framework/androidx.window.extensions.jar
D/ApplicationLoaders( 5227): Returning zygote-cached class loader: /system_ext/framework/androidx.window.sidecar.jar
D/nativeloader( 5227): Configuring clns-12 for other apk /data/app/~~gFiDFXQXZ0v7dkjp4Dcc8w==/com.google.android.gms-23rUIMQNlbIXAgjU0qGf4Q==/base.apk. target_sdk_version=37, uses_libraries=, library_path=/data/app/~~gFiDFXQXZ0v7dkjp4Dcc8w==/com.google.android.gms-23rUIMQNlbIXAgjU0qGf4Q==/lib/x86_64:/data/app/~~gFiDFXQXZ0v7dkjp4Dcc8w==/com.google.android.gms-23rUIMQNlbIXAgjU0qGf4Q==/base.apk!/lib/x86_64, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
I/grij    ( 5227): Unable to retrieve flag snapshot for com.google.android.gms.providerinstaller#io.campusconnect.campusconnect, using defaults.
I/ProviderInstaller( 5227): Installed default security provider AndroidOpenSSL (via CompatProvider)
E/GoogleApiManager( 5227): Failed to get service from broker.
E/GoogleApiManager( 5227): java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
E/GoogleApiManager( 5227): 	at android.os.Parcel.createExceptionOrNull(Parcel.java:3340)
E/GoogleApiManager( 5227): 	at android.os.Parcel.createException(Parcel.java:3324)
E/GoogleApiManager( 5227): 	at android.os.Parcel.readException(Parcel.java:3307)
E/GoogleApiManager( 5227): 	at android.os.Parcel.readException(Parcel.java:3249)
E/GoogleApiManager( 5227): 	at blbr.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):36)
E/GoogleApiManager( 5227): 	at bkzn.y(:com.google.android.gms@262634038@26.26.34 (260800-945364269):144)
E/GoogleApiManager( 5227): 	at bkfr.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):42)
E/GoogleApiManager( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
E/GoogleApiManager( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
E/GoogleApiManager( 5227): 	at deiu.mK(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
E/GoogleApiManager( 5227): 	at deiu.dispatchMessage(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
E/GoogleApiManager( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
E/GoogleApiManager( 5227): 	at android.os.Looper.loop(Looper.java:338)
E/GoogleApiManager( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
W/GoogleApiManager( 5227): Not showing notification since connectionResult is not user-facing: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagRegistrar( 5227): Failed to register com.google.android.gms.providerinstaller#io.campusconnect.campusconnect
W/FlagRegistrar( 5227): griu: 17: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagRegistrar( 5227): 	at griw.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):13)
W/FlagRegistrar( 5227): 	at hsbd.d(:com.google.android.gms@262634038@26.26.34 (260800-945364269):3)
W/FlagRegistrar( 5227): 	at hsbf.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):139)
W/FlagRegistrar( 5227): 	at hsdq.execute(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagRegistrar( 5227): 	at hsbn.f(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagRegistrar( 5227): 	at hsbn.m(:com.google.android.gms@262634038@26.26.34 (260800-945364269):101)
W/FlagRegistrar( 5227): 	at hsbn.q(:com.google.android.gms@262634038@26.26.34 (260800-945364269):16)
W/FlagRegistrar( 5227): 	at gkqg.hE(:com.google.android.gms@262634038@26.26.34 (260800-945364269):35)
W/FlagRegistrar( 5227): 	at fwqn.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):12)
W/FlagRegistrar( 5227): 	at hsdq.execute(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagRegistrar( 5227): 	at fwqo.b(:com.google.android.gms@262634038@26.26.34 (260800-945364269):18)
W/FlagRegistrar( 5227): 	at fwrd.b(:com.google.android.gms@262634038@26.26.34 (260800-945364269):34)
W/FlagRegistrar( 5227): 	at fwrf.c(:com.google.android.gms@262634038@26.26.34 (260800-945364269):23)
W/FlagRegistrar( 5227): 	at bkcy.e(:com.google.android.gms@262634038@26.26.34 (260800-945364269):9)
W/FlagRegistrar( 5227): 	at bkfp.q(:com.google.android.gms@262634038@26.26.34 (260800-945364269):48)
W/FlagRegistrar( 5227): 	at bkfp.d(:com.google.android.gms@262634038@26.26.34 (260800-945364269):10)
W/FlagRegistrar( 5227): 	at bkfp.g(:com.google.android.gms@262634038@26.26.34 (260800-945364269):191)
W/FlagRegistrar( 5227): 	at bkfp.onConnectionFailed(:com.google.android.gms@262634038@26.26.34 (260800-945364269):2)
W/FlagRegistrar( 5227): 	at bkfr.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):70)
W/FlagRegistrar( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/FlagRegistrar( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/FlagRegistrar( 5227): 	at deiu.mK(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagRegistrar( 5227): 	at deiu.dispatchMessage(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
W/FlagRegistrar( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/FlagRegistrar( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/FlagRegistrar( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
W/FlagRegistrar( 5227): Caused by: bkbd: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagRegistrar( 5227): 	at bkyz.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):15)
W/FlagRegistrar( 5227): 	at bkdb.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagRegistrar( 5227): 	at bkcy.e(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
W/FlagRegistrar( 5227): 	... 12 more
E/GoogleApiManager( 5227): Failed to get service from broker.
E/GoogleApiManager( 5227): java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
E/GoogleApiManager( 5227): 	at android.os.Parcel.createExceptionOrNull(Parcel.java:3340)
E/GoogleApiManager( 5227): 	at android.os.Parcel.createException(Parcel.java:3324)
E/GoogleApiManager( 5227): 	at android.os.Parcel.readException(Parcel.java:3307)
E/GoogleApiManager( 5227): 	at android.os.Parcel.readException(Parcel.java:3249)
E/GoogleApiManager( 5227): 	at blbr.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):36)
E/GoogleApiManager( 5227): 	at bkzn.y(:com.google.android.gms@262634038@26.26.34 (260800-945364269):144)
E/GoogleApiManager( 5227): 	at bkfr.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):42)
E/GoogleApiManager( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
E/GoogleApiManager( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
E/GoogleApiManager( 5227): 	at deiu.mK(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
E/GoogleApiManager( 5227): 	at deiu.dispatchMessage(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
E/GoogleApiManager( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
E/GoogleApiManager( 5227): 	at android.os.Looper.loop(Looper.java:338)
E/GoogleApiManager( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
W/GoogleApiManager( 5227): Not showing notification since connectionResult is not user-facing: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagStore( 5227): Unable to update local snapshot for com.google.android.gms.providerinstaller#io.campusconnect.campusconnect, may result in stale flags.
W/FlagStore( 5227): java.util.concurrent.ExecutionException: griu: 17: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagStore( 5227): 	at hsbn.j(:com.google.android.gms@262634038@26.26.34 (260800-945364269):21)
W/FlagStore( 5227): 	at hsbw.t(:com.google.android.gms@262634038@26.26.34 (260800-945364269):24)
W/FlagStore( 5227): 	at hsbn.get(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at hsgf.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):2)
W/FlagStore( 5227): 	at hsev.s(:com.google.android.gms@262634038@26.26.34 (260800-945364269):10)
W/FlagStore( 5227): 	at groe.d(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at grni.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
W/FlagStore( 5227): 	at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:524)
W/FlagStore( 5227): 	at java.util.concurrent.FutureTask.run(FutureTask.java:317)
W/FlagStore( 5227): 	at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:348)
W/FlagStore( 5227): 	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1156)
W/FlagStore( 5227): 	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:651)
W/FlagStore( 5227): 	at java.lang.Thread.run(Thread.java:1119)
W/FlagStore( 5227): Caused by: griu: 17: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagStore( 5227): 	at griw.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):13)
W/FlagStore( 5227): 	at hsbd.d(:com.google.android.gms@262634038@26.26.34 (260800-945364269):3)
W/FlagStore( 5227): 	at hsbf.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):139)
W/FlagStore( 5227): 	at hsdq.execute(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at hsbn.f(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at hsbn.m(:com.google.android.gms@262634038@26.26.34 (260800-945364269):101)
W/FlagStore( 5227): 	at hsbn.q(:com.google.android.gms@262634038@26.26.34 (260800-945364269):16)
W/FlagStore( 5227): 	at gkqg.hE(:com.google.android.gms@262634038@26.26.34 (260800-945364269):35)
W/FlagStore( 5227): 	at fwqn.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):12)
W/FlagStore( 5227): 	at hsdq.execute(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at fwqo.b(:com.google.android.gms@262634038@26.26.34 (260800-945364269):18)
W/FlagStore( 5227): 	at fwrd.b(:com.google.android.gms@262634038@26.26.34 (260800-945364269):34)
W/FlagStore( 5227): 	at fwrk.B(:com.google.android.gms@262634038@26.26.34 (260800-945364269):17)
W/FlagStore( 5227): 	at fwqf.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):60)
W/FlagStore( 5227): 	at hsdq.execute(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at fwqg.b(:com.google.android.gms@262634038@26.26.34 (260800-945364269):8)
W/FlagStore( 5227): 	at fwrd.b(:com.google.android.gms@262634038@26.26.34 (260800-945364269):34)
W/FlagStore( 5227): 	at fwrf.c(:com.google.android.gms@262634038@26.26.34 (260800-945364269):23)
W/FlagStore( 5227): 	at bkcy.e(:com.google.android.gms@262634038@26.26.34 (260800-945364269):9)
W/FlagStore( 5227): 	at bkfp.q(:com.google.android.gms@262634038@26.26.34 (260800-945364269):48)
W/FlagStore( 5227): 	at bkfp.d(:com.google.android.gms@262634038@26.26.34 (260800-945364269):10)
W/FlagStore( 5227): 	at bkfp.g(:com.google.android.gms@262634038@26.26.34 (260800-945364269):191)
W/FlagStore( 5227): 	at bkfp.onConnectionFailed(:com.google.android.gms@262634038@26.26.34 (260800-945364269):2)
W/FlagStore( 5227): 	at bkfr.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):70)
W/FlagStore( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
W/FlagStore( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
W/FlagStore( 5227): 	at deiu.mK(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at deiu.dispatchMessage(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
W/FlagStore( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
W/FlagStore( 5227): 	at android.os.Looper.loop(Looper.java:338)
W/FlagStore( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
W/FlagStore( 5227): Caused by: bkbd: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagStore( 5227): 	at bkyz.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):15)
W/FlagStore( 5227): 	at bkdb.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
W/FlagStore( 5227): 	at bkcy.e(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
W/FlagStore( 5227): 	... 12 more
W/System  ( 5227): Ignoring header X-Firebase-Locale because its value was null.
W/LocalRequestInterceptor( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/ImeTracker( 5227): io.campusconnect.campusconnect:8409e93f: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:73a8da5f: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
E/GoogleApiManager( 5227): Failed to get service from broker.
E/GoogleApiManager( 5227): java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
E/GoogleApiManager( 5227): 	at android.os.Parcel.createExceptionOrNull(Parcel.java:3340)
E/GoogleApiManager( 5227): 	at android.os.Parcel.createException(Parcel.java:3324)
E/GoogleApiManager( 5227): 	at android.os.Parcel.readException(Parcel.java:3307)
E/GoogleApiManager( 5227): 	at android.os.Parcel.readException(Parcel.java:3249)
E/GoogleApiManager( 5227): 	at blbr.a(:com.google.android.gms@262634038@26.26.34 (260800-945364269):36)
E/GoogleApiManager( 5227): 	at bkzn.y(:com.google.android.gms@262634038@26.26.34 (260800-945364269):144)
E/GoogleApiManager( 5227): 	at bkfr.run(:com.google.android.gms@262634038@26.26.34 (260800-945364269):42)
E/GoogleApiManager( 5227): 	at android.os.Handler.handleCallback(Handler.java:995)
E/GoogleApiManager( 5227): 	at android.os.Handler.dispatchMessage(Handler.java:103)
E/GoogleApiManager( 5227): 	at deiu.mK(:com.google.android.gms@262634038@26.26.34 (260800-945364269):1)
E/GoogleApiManager( 5227): 	at deiu.dispatchMessage(:com.google.android.gms@262634038@26.26.34 (260800-945364269):5)
E/GoogleApiManager( 5227): 	at android.os.Looper.loopOnce(Looper.java:248)
E/GoogleApiManager( 5227): 	at android.os.Looper.loop(Looper.java:338)
E/GoogleApiManager( 5227): 	at android.os.HandlerThread.run(HandlerThread.java:85)
W/GoogleApiManager( 5227): Not showing notification since connectionResult is not user-facing: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
D/FirebaseAuth( 5227): Notifying id token listeners about a sign-out event.
D/FirebaseAuth( 5227): Notifying auth state listeners about a sign-out event.
I/t.campusconnect( 5227): AssetManager2(0x7c7074d20938) locale list changing from [] to [en-US]
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@217dd88
I/ImeTracker( 5227): io.campusconnect.campusconnect:51b007a4: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/AssistStructure( 5227): Flattened final assist data: 512 bytes, containing 1 windows, 3 views
I/ImeTracker( 5227): io.campusconnect.campusconnect:51b007a4: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:79d9708f: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:79d9708f: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/AssistStructure( 5227): Flattened final assist data: 504 bytes, containing 1 windows, 3 views
I/FirebaseAuth( 5227): Logging in as ajayak@jdcoem.ac.in with empty reCAPTCHA token
W/System  ( 5227): Ignoring header X-Firebase-Locale because its value was null.
W/LocalRequestInterceptor( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
W/System  ( 5227): Ignoring header X-Firebase-Locale because its value was null.
W/LocalRequestInterceptor( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
D/FirebaseAuth( 5227): Notifying id token listeners about user ( ynleASY3m0dJ0dVkQ6D9K1xMVKv2 ).
D/FirebaseAuth( 5227): Notifying auth state listeners about user ( ynleASY3m0dJ0dVkQ6D9K1xMVKv2 ).
I/ImeTracker( 5227): io.campusconnect.campusconnect:df72275: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/t.campusconnect( 5227): hiddenapi: Accessing hidden method Ldalvik/system/CloseGuard;->get()Ldalvik/system/CloseGuard; (runtime_flags=CorePlatformApi, domain=core-platform, api=unsupported,core-platform-api) from Lokhttp3/internal/platform/AndroidPlatform$CloseGuard; (domain=app) using reflection: allowed
I/t.campusconnect( 5227): hiddenapi: Accessing hidden method Ldalvik/system/CloseGuard;->open(Ljava/lang/String;)V (runtime_flags=CorePlatformApi, domain=core-platform, api=unsupported,core-platform-api) from Lokhttp3/internal/platform/AndroidPlatform$CloseGuard; (domain=app) using reflection: allowed
I/t.campusconnect( 5227): hiddenapi: Accessing hidden method Ldalvik/system/CloseGuard;->warnIfOpen()V (runtime_flags=CorePlatformApi, domain=core-platform, api=unsupported,core-platform-api) from Lokhttp3/internal/platform/AndroidPlatform$CloseGuard; (domain=app) using reflection: allowed
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/ImeTracker( 5227): system_server:21fb3700: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): PortfolioService.getPortfolio: doc USERS/ynleASY3m0dJ0dVkQ6D9K1xMVKv2 EXISTS but portfolio key is MISSING. Doc keys present: (metadata, role, personal.email)
I/flutter ( 5227): ResumeReviewProvider: Loaded 0 history items
I/ImeTracker( 5227): io.campusconnect.campusconnect:3d9e9bd: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:3d9e9bd: onShown
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
I/ImeTracker( 5227): io.campusconnect.campusconnect:1c790736: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:1c790736: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:77424cc6: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:77424cc6: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:c94bbbc0: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:c94bbbc0: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:19a44d0b: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:5be4e1b5: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@217dd88
I/ImeTracker( 5227): io.campusconnect.campusconnect:73e97f5d: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:73e97f5d: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:fda9a7e5: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:fda9a7e5: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:51e09d5d: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:51e09d5d: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:7b86f241: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:7b86f241: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:95beed6f: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:95beed6f: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:bf5cddbf: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:6608c827: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
I/ImeTracker( 5227): io.campusconnect.campusconnect:bf78899d: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:bf78899d: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:146a836: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:146a836: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:f2c41b0d: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:f2c41b0d: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:c14e89b7: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:c14e89b7: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:fa8555cb: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:fa8555cb: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:feba27a4: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:feba27a4: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:1b6ebeb0: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:1b6ebeb0: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:6fed01b2: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:70fc72a1: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
I/ImeTracker( 5227): io.campusconnect.campusconnect:71764739: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:71764739: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:52070093: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:761f3eef: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
I/ImeTracker( 5227): io.campusconnect.campusconnect:e1c6b195: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:e1c6b195: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:8a1d8189: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:8a1d8189: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:170853e6: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:170853e6: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:f6dfd557: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:f6dfd557: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:7ed9b6b7: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:7ed9b6b7: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:bb456b06: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:bb456b06: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:e9020bb6: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:e9020bb6: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:effbdef2: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:8d209bdf: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
I/ImeTracker( 5227): io.campusconnect.campusconnect:eb657523: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:eb657523: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:82b349d8: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:82b349d8: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:605a3538: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:605a3538: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:98b9e2b2: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:98b9e2b2: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:13ad4cd9: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:13ad4cd9: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:1166e1e3: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:1166e1e3: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:bb8fece4: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:1fb89c30: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
I/ImeTracker( 5227): io.campusconnect.campusconnect:8ff34b41: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:8ff34b41: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:bdac205a: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:bdac205a: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:8bfe8834: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:8bfe8834: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:7b9e7f4f: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:7b9e7f4f: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:8825ca0e: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:8825ca0e: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:b973d9a4: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:b973d9a4: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:b0b1715: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:b0b1715: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:ffe11a61: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:7dc6da01: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
I/ImeTracker( 5227): io.campusconnect.campusconnect:db81589f: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:db81589f: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:b83a03f8: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:b83a03f8: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:8501b455: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:8501b455: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:7116da7d: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:7116da7d: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:5a87190b: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:5a87190b: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:dfecabeb: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:dfecabeb: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:1e112a38: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:38cc1555: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
I/ImeTracker( 5227): io.campusconnect.campusconnect:dfacad16: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
D/InsetsController( 5227): Setting requestedVisibleTypes to -1 (was -9)
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:dfacad16: onShown
I/ImeTracker( 5227): io.campusconnect.campusconnect:e9458acf: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:e9458acf: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
D/InputConnectionAdaptor( 5227): The input method toggled cursor monitoring on
I/ImeTracker( 5227): io.campusconnect.campusconnect:97b827d2: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:97b827d2: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:de78efd0: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser false
D/InsetsController( 5227): show(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:de78efd0: onCancelled at PHASE_CLIENT_APPLY_ANIMATION
I/ImeTracker( 5227): io.campusconnect.campusconnect:39492483: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser false
D/InsetsController( 5227): hide(ime(), fromIme=false)
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=android.view.ImeBackAnimationController@27e239c
D/InsetsController( 5227): Setting requestedVisibleTypes to -9 (was -1)
I/ImeTracker( 5227): system_server:e06a9530: onCancelled at PHASE_CLIENT_ON_CONTROLS_CHANGED
D/FilePickerUtils( 5227): Allowed file extensions mimes: [application/pdf]
D/FilePickerDelegate( 5227): Selected type */*
D/VRI[MainActivity]( 5227): visibilityChanged oldVisibility=true newVisibility=false
I/FA      ( 5227): Application backgrounded at: timestamp_millis: 1786879812333
I/AutofillManager( 5227): onInvisibleForAutofill(): expiringResponse
D/ViewRootImpl( 5227): Skipping stats log for color mode
I/FilePickerUtils( 5227): Caching from URI: content://com.android.providers.media.documents/document/document%3A44
D/FilePickerUtils( 5227): File loaded and cached at:/data/user/0/io.campusconnect.campusconnect/cache/file_picker/1786879816686/resume.pdf
D/FilePickerDelegate( 5227): File path:[com.mr.flutter.plugin.filepicker.FileInfo@92162ce]
W/StorageUtil( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
D/InsetsController( 5227): hide(ime(), fromIme=false)
I/ImeTracker( 5227): io.campusconnect.campusconnect:6adfc245: onCancelled at PHASE_CLIENT_ALREADY_HIDDEN
D/UploadTask( 5227): Waiting 0 milliseconds
W/StorageUtil( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
W/StorageTask( 5227): unable to change internal state to: INTERNAL_STATE_CANCELED, INTERNAL_STATE_CANCELING isUser: true from state:INTERNAL_STATE_SUCCESS
W/StorageUtil( 5227): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@217dd88
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
I/t.campusconnect( 5227): AssetManager2(0x7c7074d17018) locale list changing from [] to [en-US]
I/flutter ( 5227): ResumeReviewProvider: Submitting review...
I/flutter ( 5227): ResumeReviewService: Sending review request...
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): ResumeReviewProvider: Review complete. ATS Score: 68
I/flutter ( 5227): ResumeHistoryService: Saved review IFMGcKOhpJ3uPQqYiPrv
I/flutter ( 5227): ResumeReviewProvider: Saved review to history: IFMGcKOhpJ3uPQqYiPrv
I/flutter ( 5227): ResumeReviewProvider: Refreshed 1 history items
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@217dd88
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
W/WindowOnBackDispatcher( 5227): sendCancelIfRunning: isInProgress=false callback=io.flutter.embedding.android.FlutterActivity$1@217dd88
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
W/FirebaseContextProvider( 5227): Error getting App Check token. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
I/flutter ( 5227): RecommendationService: server regenerated recommendations for ynleASY3m0dJ0dVkQ6D9K1xMVKv2
