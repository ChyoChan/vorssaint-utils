// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct SoundPanelStrings {
    let title: String
    let appVolumes: String
    let soundSettings: String
    let volumeUnavailable: String
}

extension FeatureStrings {
    static func soundPanel(_ language: AppLanguage) -> SoundPanelStrings {
        switch language {
        case .enUS:
            return .init(title: "Sound", appVolumes: "App Volumes", soundSettings: "Sound Settings…",
                         volumeUnavailable: "Use the volume controls on this device.")
        case .ptBR:
            return .init(title: "Som", appVolumes: "Volume dos apps", soundSettings: "Ajustes de Som…",
                         volumeUnavailable: "Use os controles de volume deste dispositivo.")
        case .tr:
            return .init(title: "Ses", appVolumes: "Uygulama sesleri", soundSettings: "Ses Ayarları…",
                         volumeUnavailable: "Bu aygıtın ses denetimlerini kullanın.")
        case .ru:
            return .init(title: "Звук", appVolumes: "Громкость приложений", soundSettings: "Настройки звука…",
                         volumeUnavailable: "Используйте регулятор громкости на этом устройстве.")
        case .es:
            return .init(title: "Sonido", appVolumes: "Volumen de las apps", soundSettings: "Ajustes de Sonido…",
                         volumeUnavailable: "Usa los controles de volumen de este dispositivo.")
        case .sk:
            return .init(title: "Zvuk", appVolumes: "Hlasitosť aplikácií", soundSettings: "Nastavenia zvuku…",
                         volumeUnavailable: "Použite ovládanie hlasitosti na tomto zariadení.")
        case .de:
            return .init(title: "Ton", appVolumes: "App-Lautstärken", soundSettings: "Toneinstellungen…",
                         volumeUnavailable: "Verwende die Lautstärkeregler dieses Geräts.")
        case .fr:
            return .init(title: "Son", appVolumes: "Volume des apps", soundSettings: "Réglages Son…",
                         volumeUnavailable: "Utilisez les commandes de volume de cet appareil.")
        case .it:
            return .init(title: "Suono", appVolumes: "Volume delle app", soundSettings: "Impostazioni Suono…",
                         volumeUnavailable: "Usa i controlli del volume di questo dispositivo.")
        case .ja:
            return .init(title: "サウンド", appVolumes: "アプリの音量", soundSettings: "サウンド設定…",
                         volumeUnavailable: "このデバイスの音量コントロールを使用してください。")
        case .ko:
            return .init(title: "사운드", appVolumes: "앱 음량", soundSettings: "사운드 설정…",
                         volumeUnavailable: "이 기기의 음량 조절 기능을 사용하세요.")
        case .zhHans:
            return .init(title: "声音", appVolumes: "App 音量", soundSettings: "声音设置…",
                         volumeUnavailable: "请使用此设备本身的音量控制。")
        case .zhTW:
            return .init(title: "聲音", appVolumes: "App 音量", soundSettings: "聲音設定…",
                         volumeUnavailable: "請使用此裝置本身的音量控制。")
        case .zhHK:
            return .init(title: "聲音", appVolumes: "App 音量", soundSettings: "聲音設定…",
                         volumeUnavailable: "請使用此裝置本身的音量控制。")
        case .uk:
            return .init(title: "Звук", appVolumes: "Гучність програм", soundSettings: "Параметри звуку…",
                         volumeUnavailable: "Використовуйте регулятор гучності на цьому пристрої.")
        }
    }
}
