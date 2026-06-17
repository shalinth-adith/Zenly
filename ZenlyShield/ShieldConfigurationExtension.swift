//
//  ShieldConfigurationExtension.swift
//  ZenlyShield
//
//  Supplies the UI shown over a blocked app/website. Phase 1 stub: returns the
//  system default shield. Phase 1 (next pass) replaces these with Zenly's calm,
//  redirecting shield (custom title, icon, accent, "5s override" affordance).
//

import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
