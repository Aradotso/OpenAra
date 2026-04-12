```markdown
---
name: vpn-detector-android
description: Android library/app for detecting VPN usage, network tunneling signals, and split tunneling via NetworkCapabilities, interface inspection, and package enumeration.
triggers:
  - detect VPN on Android
  - check if VPN is active Android
  - NetworkCapabilities TRANSPORT_VPN
  - detect split tunneling Android
  - tun0 wg0 interface detection
  - enumerate VPN apps Android
  - VPN detection Kotlin
  - check network tunneling Android
---

# Android VPN Detector

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

Research tool and reusable detection logic for analyzing VPN presence on Android, including full tunnels, split tunneling, and known VPN client enumeration.

## What It Does

- Detects active VPN via `NetworkCapabilities.TRANSPORT_VPN`
- Distinguishes active vs. global VPN state
- Inspects network interfaces (`tun0`, `wg0`, etc.)
- Enumerates installed packages to identify known VPN clients
- Works even when split tunneling is enabled (app bypass mode)

## Project Structure

```
app/
  src/main/java/com/cherepavel/vpndetector/
    VpnDetector.kt          # Core detection logic
    InterfaceDetector.kt    # Native/Java network interface inspection
    PackageDetector.kt      # VPN app enumeration via PackageManager
    MainActivity.kt         # UI / demo activity
  src/main/res/
  AndroidManifest.xml
```

## Installation / Integration

### As a Module Dependency

Copy the detection classes into your project or add as a Git submodule:

```bash
git clone https://github.com/cherepavel/VPN-Detector.git
```

Copy relevant files into your app module:
- `VpnDetector.kt`
- `InterfaceDetector.kt`
- `PackageDetector.kt`

### Required Permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

> `QUERY_ALL_PACKAGES` requires justification for Google Play submissions. Use it only for research/enterprise apps or replace with a curated package list.

## Core API & Usage

### 1. Detect VPN via NetworkCapabilities

```kotlin
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

fun isVpnActive(context: Context): Boolean {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val network = cm.activeNetwork ?: return false
    val caps = cm.getNetworkCapabilities(network) ?: return false
    return caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
}
```

### 2. Check All Networks (Catches Split Tunnel)

```kotlin
fun isVpnActiveOnAnyNetwork(context: Context): Boolean {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    return cm.allNetworks.any { network ->
        cm.getNetworkCapabilities(network)
            ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
    }
}
```

### 3. Interface-Level Detection (tun0, wg0, ppp0)

```kotlin
import java.net.NetworkInterface

fun detectVpnInterfaces(): List<String> {
    val vpnPrefixes = listOf("tun", "wg", "ppp", "tap", "ipsec", "utun")
    return try {
        NetworkInterface.getNetworkInterfaces()
            ?.toList()
            ?.filter { iface ->
                iface.isUp && vpnPrefixes.any { prefix ->
                    iface.name.startsWith(prefix)
                }
            }
            ?.map { it.name }
            ?: emptyList()
    } catch (e: Exception) {
        emptyList()
    }
}

fun hasVpnInterface(): Boolean = detectVpnInterfaces().isNotEmpty()
```

### 4. Detect Known VPN Apps via PackageManager

```kotlin
import android.content.Context
import android.content.pm.PackageManager

val knownVpnPackages = listOf(
    "com.expressvpn.vpn",
    "com.nordvpn.android",
    "com.privateinternetaccess.android",
    "com.surfshark.vpnclient.android",
    "org.torproject.android",
    "com.protonvpn.android",
    "com.mullvad.vpn",
    "com.wireguard.android",
    "net.openvpn.openvpn",
    "com.strongswan.android.app"
)

fun getInstalledVpnApps(context: Context): List<String> {
    val pm = context.packageManager
    return knownVpnPackages.filter { pkg ->
        try {
            pm.getPackageInfo(pkg, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
```

### 5. Combined Detection Result

```kotlin
data class VpnDetectionResult(
    val isVpnOnActiveNetwork: Boolean,
    val isVpnOnAnyNetwork: Boolean,
    val vpnInterfaces: List<String>,
    val installedVpnApps: List<String>
) {
    val isVpnDetected: Boolean
        get() = isVpnOnActiveNetwork || isVpnOnAnyNetwork || vpnInterfaces.isNotEmpty()

    val isSplitTunnel: Boolean
        get() = isVpnOnAnyNetwork && !isVpnOnActiveNetwork
}

fun detectVpn(context: Context): VpnDetectionResult {
    return VpnDetectionResult(
        isVpnOnActiveNetwork = isVpnActive(context),
        isVpnOnAnyNetwork = isVpnActiveOnAnyNetwork(context),
        vpnInterfaces = detectVpnInterfaces(),
        installedVpnApps = getInstalledVpnApps(context)
    )
}
```

### 6. Observe Network Changes (Real-Time)

```kotlin
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest

fun registerVpnCallback(
    context: Context,
    onVpnConnected: (Network) -> Unit,
    onVpnDisconnected: (Network) -> Unit
): ConnectivityManager.NetworkCallback {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    val request = NetworkRequest.Builder()
        .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
        .build()

    val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = onVpnConnected(network)
        override fun onLost(network: Network) = onVpnDisconnected(network)
    }

    cm.registerNetworkCallback(request, callback)
    return callback // Store to unregister later
}

// Unregister when done (e.g., in onDestroy):
// cm.unregisterNetworkCallback(callback)
```

## Common Patterns

### In a ViewModel

```kotlin
class NetworkViewModel(application: Application) : AndroidViewModel(application) {

    private val _vpnState = MutableLiveData<VpnDetectionResult>()
    val vpnState: LiveData<VpnDetectionResult> = _vpnState

    private val cm = application.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) { refresh() }
        override fun onLost(network: Network) { refresh() }
        override fun onCapabilitiesChanged(
            network: Network,
            caps: NetworkCapabilities
        ) { refresh() }
    }

    init {
        val request = NetworkRequest.Builder().build()
        cm.registerNetworkCallback(request, networkCallback)
        refresh()
    }

    fun refresh() {
        _vpnState.postValue(detectVpn(getApplication()))
    }

    override fun onCleared() {
        cm.unregisterNetworkCallback(networkCallback)
    }
}
```

### In a Composable (Jetpack Compose)

```kotlin
@Composable
fun VpnStatusScreen(context: Context) {
    var result by remember { mutableStateOf<VpnDetectionResult?>(null) }

    LaunchedEffect(Unit) {
        result = detectVpn(context)
    }

    result?.let { vpn ->
        Column(modifier = Modifier.padding(16.dp)) {
            Text("VPN Active: ${vpn.isVpnDetected}")
            Text("Split Tunnel: ${vpn.isSplitTunnel}")
            Text("Interfaces: ${vpn.vpnInterfaces.joinToString()}")
            Text("VPN Apps Found: ${vpn.installedVpnApps.size}")
        }
    }
}
```

### In a Service or Background Check

```kotlin
class VpnCheckService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val result = detectVpn(applicationContext)
        if (result.isVpnDetected) {
            // Log, notify, or restrict functionality
            Log.w("VpnCheck", "VPN detected: interfaces=${result.vpnInterfaces}")
        }
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
```

## Split Tunneling Detection

Split tunneling allows specific apps to bypass the VPN. Detection strategy:

```kotlin
fun analyzeSplitTunnel(context: Context): String {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val activeNetwork = cm.activeNetwork
    val activeCaps = activeNetwork?.let { cm.getNetworkCapabilities(it) }

    val activeHasVpn = activeCaps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
    val anyHasVpn = cm.allNetworks.any {
        cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
    }

    return when {
        activeHasVpn -> "FULL_TUNNEL — VPN is active network"
        anyHasVpn    -> "SPLIT_TUNNEL — VPN exists but app is bypassed"
        else         -> "NO_VPN"
    }
}
```

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| `TRANSPORT_VPN` not detected | App is in VPN bypass list | Check `allNetworks`, not just `activeNetwork` |
| Interface list empty | SecurityException on some ROMs | Wrap in try/catch; falls back gracefully |
| `QUERY_ALL_PACKAGES` denied | Missing permission or Play policy | Use curated package list without the permission |
| NetworkCallback not firing | Callback registered after VPN connected | Call `detectVpn()` immediately on registration |
| False positive on emulator | Emulator network presented as VPN | Filter by interface name to confirm |

## Limitations & Notes

- `NetworkCapabilities.TRANSPORT_VPN` requires API 21+
- Some WireGuard implementations may not expose `tun` interfaces on all devices
- `QUERY_ALL_PACKAGES` is restricted on Google Play — use a known-packages list instead for production
- VPN apps using the `VpnService` API will always show `TRANSPORT_VPN` on their managed network
- Root-level VPN implementations (kernel modules) may evade all Java-layer detection
```
