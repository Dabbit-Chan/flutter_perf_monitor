import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { hidebug } from '@kit.PerformanceAnalysisKit';

/** FlutterPerfMonitorPlugin **/
export default class FlutterPerfMonitorPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "FlutterPerfMonitorPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_perf_monitor");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "getMemoryInfo") {
      try {
        // hidebug.getSystemMemInfo() 同步返回系统内存信息。
        // SystemMemInfo 的 totalMem / freeMem / availableMem 均为 bigint，单位为字节。
        const systemMemInfo: hidebug.SystemMemInfo = hidebug.getSystemMemInfo();

        const totalMemory = Number(systemMemInfo.totalMem);
        const freeMemory = Number(systemMemInfo.freeMem);
        const usedMemory = totalMemory - freeMemory;
        const percentUsed = totalMemory > 0 ? (usedMemory / totalMemory) * 100 : 0;

        const memoryInfo = new Map<string, number>();
        // Dart 端 _updateNativeMetrics 读取 totalMemory / availableMemory（字节，int）
        // 额外返回 usedMemory / percentUsed，与 Android、iOS 实现保持一致
        memoryInfo.set("totalMemory", totalMemory);
        memoryInfo.set("availableMemory", freeMemory);
        memoryInfo.set("usedMemory", usedMemory);
        memoryInfo.set("percentUsed", percentUsed);

        console.info(`getMemoryInfo: totalMem=${systemMemInfo.totalMem}, freeMem=${systemMemInfo.freeMem}, availableMem=${systemMemInfo.availableMem}`);
        result.success(memoryInfo);
      } catch (err) {
        console.error("getMemoryInfo failed with error: " + JSON.stringify(err));
        result.error("MEMORY_ERROR", "Failed to get memory info", JSON.stringify(err));
      }
    } else if (call.method == "getCpuUsage") {
      try {
        // hidebug.getCpuUsage() 返回当前进程的 CPU 使用率，为 0~1 的小数（如 50% 返回 0.5）。
        // 鸿蒙无法跨进程读取系统文件（如 /proc/stat）计算整机 CPU，只能获取进程级使用率。
        const cpuUsage: number = hidebug.getCpuUsage();
        // 转换为 0~100 的百分比，与 Dart 端期望对齐
        const totalUsage = cpuUsage * 100;
        // ohos 不暴露 per-core CPU 信息，返回空列表（Dart 端可正常处理）
        const perCoreUsage: number[] = [];

        const cpuInfo = new Map<string, Object>();
        cpuInfo.set("totalUsage", totalUsage);
        cpuInfo.set("perCoreUsage", perCoreUsage);

        console.info(`getCpuUsage: processCpuUsage=${cpuUsage}, totalUsage=${totalUsage}%`);
        result.success(cpuInfo);
      } catch (err) {
        console.error("getCpuUsage failed with error: " + JSON.stringify(err));
        result.error("CPU_ERROR", "Failed to get CPU usage", JSON.stringify(err));
      }
    } else {
      result.notImplemented()
    }
  }
}