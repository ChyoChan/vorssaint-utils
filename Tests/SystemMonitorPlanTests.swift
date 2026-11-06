// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Runs the production sampling plan against scripted surfaces and features.
enum SystemMonitorPlanTests {
    enum PowerSampler { static var hasInternalBattery = false }

    class Fixture {
        var menuPanelNeeds = SystemMonitorPanelNeeds.none
        var notchDetailNeeds = SystemMonitorPanelNeeds.none
        var fullMonitorVisible = false
        var notchVisible = false
        var notchAccessoryMonitoring = false
        var screensSleeping = false
        static var fanTelemetryAvailable: Bool { true }
    }

    /// The panel's own state for its shipped `monitorNeeds`; the Power card
    /// is what matters here, so the other sections stay out.
    enum PanelSectionID { case keepAwake, system, network, disk, power }

    class PanelFixture {
        var selectedMetric: MetricDetailKind?
        var activeSection = PanelSectionID.keepAwake
        var showingKeepAwakeOnly = false
    }

    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.system-monitor-plan"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: AppFeature.connectedDevices.availabilityKey)
        defaults.set(true, forKey: AppFeature.fanControl.availabilityKey)
        let monitor = Monitor()

        suite.expect(!monitor.currentPlan(defaults: defaults).needConnectedDevices,
                     "connected devices are not read while no surface shows them")
        monitor.menuPanelNeeds = SystemMonitorPanelNeeds(system: true)
        defaults.set(true, forKey: DefaultsKey.monitorSysConnectedDevices)
        suite.expect(monitor.currentPlan(defaults: defaults).needConnectedDevices,
                     "the panel's System card reads connected devices for its device row")
        defaults.set(false, forKey: DefaultsKey.monitorSysConnectedDevices)
        suite.expect(!monitor.currentPlan(defaults: defaults).needConnectedDevices,
                     "a hidden device row stops the System card's USB reads")
        monitor.menuPanelNeeds = SystemMonitorPanelNeeds(connectedDevices: true)
        suite.expect(monitor.currentPlan(defaults: defaults).needConnectedDevices,
                     "the device list still reads connected devices with the System row hidden")
        monitor.menuPanelNeeds = .none
        monitor.notchDetailNeeds = SystemMonitorPanelNeeds(connectedDevices: true)
        suite.expect(monitor.currentPlan(defaults: defaults).needConnectedDevices,
                     "the island System page's device card ignores the panel row's toggle")
        monitor.notchDetailNeeds = .none
        monitor.fullMonitorVisible = true
        let preview = monitor.currentPlan(defaults: defaults)
        suite.expect(preview.needConnectedDevices && preview.needFanSpeed,
                     "the Settings island preview reads connected devices for its card, like the fan card")
        defaults.set(false, forKey: AppFeature.connectedDevices.availabilityKey)
        suite.expect(!monitor.currentPlan(defaults: defaults).needConnectedDevices,
                     "an uninstalled connected devices feature is not read, even for the preview")

        monitor.fullMonitorVisible = false
        monitor.menuPanelNeeds = SystemMonitorPanelNeeds(system: true)
        defaults.set(true, forKey: AppFeature.monitorCPU.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.menuBarCPU)
        defaults.set(true, forKey: DefaultsKey.monitorSysCPU)
        defaults.set(true, forKey: DefaultsKey.monitorSysCPUCores)
        suite.expect(monitor.currentPlan(defaults: defaults).needCPUCores,
                     "the panel's CPU row reads every core for its per-core bars")
        defaults.set(false, forKey: DefaultsKey.monitorSysCPU)
        let menuBarCPU = monitor.currentPlan(defaults: defaults)
        suite.expect(menuBarCPU.needCPU && !menuBarCPU.needCPUCores,
                     "a CPU shown only in the menu bar does not read every core while the panel hides its CPU row")
        defaults.set(true, forKey: DefaultsKey.monitorSysCPU)
        defaults.set(false, forKey: DefaultsKey.monitorSysCPUCores)
        suite.expect(!monitor.currentPlan(defaults: defaults).needCPUCores,
                     "the Per core switch stops reading every core")
        defaults.set(true, forKey: DefaultsKey.monitorSysCPUCores)
        monitor.menuPanelNeeds = .none
        suite.expect(!monitor.currentPlan(defaults: defaults).needCPUCores,
                     "a closed panel does not read every core")
        monitor.menuPanelNeeds = SystemMonitorPanelNeeds(system: true)
        defaults.set(false, forKey: AppFeature.monitorCPU.availabilityKey)
        suite.expect(!monitor.currentPlan(defaults: defaults).needCPUCores,
                     "an uninstalled CPU monitor does not read every core")

        let panel = Panel()
        panel.activeSection = .power
        panel.showingKeepAwakeOnly = true
        suite.expect(panel.monitorNeeds == .none,
                     "the dedicated Keep Awake panel does not sample the previously selected Power card")
        panel.selectedMetric = .battery
        suite.expect(panel.monitorNeeds == .none,
                     "the dedicated Keep Awake panel does not sample a previously selected metric detail")
        panel.showingKeepAwakeOnly = false
        panel.selectedMetric = nil
        monitor.menuPanelNeeds = panel.monitorNeeds
        defaults.set(true, forKey: AppFeature.monitorPower.availabilityKey)
        defaults.set(false, forKey: DefaultsKey.menuBarPeripheralBattery)
        defaults.set(true, forKey: DefaultsKey.monitorPwrPeripherals)
        suite.expect(monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "the Power card reads peripheral batteries with the menu bar option off")
        defaults.set(false, forKey: DefaultsKey.monitorPwrPeripherals)
        suite.expect(!monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "hiding the Power card's peripheral row stops the reads")
        defaults.set(true, forKey: DefaultsKey.menuBarPeripheralBattery)
        suite.expect(monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "the menu bar option still reads peripheral batteries on its own")
        defaults.set(false, forKey: DefaultsKey.menuBarPeripheralBattery)
        defaults.set(true, forKey: DefaultsKey.monitorPwrPeripherals)
        defaults.set(false, forKey: AppFeature.monitorPower.availabilityKey)
        suite.expect(!monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "an uninstalled Power monitor reads no peripheral battery for its card")
        defaults.set(true, forKey: AppFeature.monitorPower.availabilityKey)
        monitor.menuPanelNeeds = .none
        suite.expect(!monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "a closed panel does not read peripheral batteries")
        panel.selectedMetric = .power
        monitor.menuPanelNeeds = panel.monitorNeeds
        suite.expect(!monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "the Power and Battery time detail does not read peripheral batteries")
        monitor.menuPanelNeeds = .none
        monitor.notchDetailNeeds = MetricDetailKind.power.monitorNeeds
        suite.expect(!monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "the island's Power detail does not read peripheral batteries")
        monitor.notchDetailNeeds = .none
        monitor.fullMonitorVisible = true
        suite.expect(!monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "the Settings island preview shows no peripheral battery and does not read one")
        monitor.fullMonitorVisible = false
        defaults.set(false, forKey: DefaultsKey.monitorPwrPeripherals)
        panel.selectedMetric = .battery
        monitor.menuPanelNeeds = panel.monitorNeeds
        suite.expect(monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "the Battery detail still lists peripherals with the Power row hidden")
        monitor.menuPanelNeeds = .none
        monitor.notchDetailNeeds = MetricDetailKind.battery.monitorNeeds
        suite.expect(monitor.currentPlan(defaults: defaults).needPeripheralBattery,
                     "the island's Battery detail still lists peripherals with the Power row hidden")
        monitor.notchDetailNeeds = .none
        monitor.fullMonitorVisible = true
        monitor.notchVisible = true
        monitor.notchAccessoryMonitoring = true
        for feature in [AppFeature.monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk,
                        .monitorPower, .connectedDevices] {
            defaults.set(true, forKey: feature.availabilityKey)
        }
        for key in [DefaultsKey.menuBarCPU, DefaultsKey.menuBarGPU, DefaultsKey.menuBarMemory,
                    DefaultsKey.menuBarNetwork, DefaultsKey.menuBarDiskActivity, DefaultsKey.menuBarPower,
                    DefaultsKey.menuBarPeripheralBattery, DefaultsKey.menuBarCPUTemperature,
                    DefaultsKey.menuBarGPUTemperature, DefaultsKey.menuBarFanSpeed,
                    DefaultsKey.menuBarConnectedDevices] {
            defaults.set(true, forKey: key)
        }
        suite.expect(monitor.currentPlan(defaults: defaults).needGPUUsage,
                     "awake displays retain their configured monitor readings")
        monitor.screensSleeping = true
        suite.expect(!monitor.currentPlan(defaults: defaults).any,
                     "sleeping displays stop all presentation-only sampling, including retained panels and pinned metrics")
        PowerSampler.hasInternalBattery = true
        defer { PowerSampler.hasInternalBattery = false }
        for key in [DefaultsKey.monitorAlertCPU, DefaultsKey.monitorAlertMemory, DefaultsKey.monitorAlertDisk,
                    DefaultsKey.monitorAlertBattery, DefaultsKey.monitorAlertCPUTemperature,
                    DefaultsKey.monitorAlertBatteryTemperature] {
            defaults.set(true, forKey: key)
        }
        let sleepingAlerts = monitor.currentPlan(defaults: defaults)
        suite.expect(sleepingAlerts.needCPU && sleepingAlerts.needMemory && sleepingAlerts.needDisk
                     && sleepingAlerts.needPower && sleepingAlerts.needCPUTemperature && sleepingAlerts.needBatteryTemperature,
                     "screen sleep preserves every enabled alert's necessary reading")
        suite.expect(!sleepingAlerts.needGPUUsage && !sleepingAlerts.needNetwork && !sleepingAlerts.needFanSpeed
                     && !sleepingAlerts.needCPUCores && !sleepingAlerts.needPeripheralBattery
                     && !sleepingAlerts.needConnectedDevices && !sleepingAlerts.needChipTemperatureMenuBar,
                     "sleeping alert monitoring does not inherit pinned display work or fast temperature cadence")
        defaults.set(false, forKey: AppFeature.monitorCPU.availabilityKey)
        suite.expect(!monitor.currentPlan(defaults: defaults).needCPU && !monitor.currentPlan(defaults: defaults).needCPUTemperature,
                     "sleeping alerts still respect disabled metric families")
        defaults.set(true, forKey: AppFeature.monitorCPU.availabilityKey)
        monitor.screensSleeping = false
        let waking = monitor.currentPlan(defaults: defaults)
        suite.expect(waking.needGPUUsage && waking.needNetwork && waking.needFanSpeed
                     && waking.needPeripheralBattery && waking.needConnectedDevices && waking.needChipTemperatureMenuBar,
                     "waking restores presentation sampling without changing pinned metric preferences")
    }
}
