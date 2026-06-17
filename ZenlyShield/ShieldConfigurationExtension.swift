//
//  ShieldConfigurationExtension.swift
//  ZenlyShield
//
//  Supplies the calm custom shield shown over a blocked app/website. iOS calls
//  the relevant overload depending on whether the block came from an app, a
//  website, or a category. We personalize with the subject's name when available.
//

import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        DistractionLog.recordAttempt()
        return ShieldTheme.configuration(subject: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        DistractionLog.recordAttempt()
        return ShieldTheme.configuration(subject: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        DistractionLog.recordAttempt()
        return ShieldTheme.configuration(subject: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        DistractionLog.recordAttempt()
        return ShieldTheme.configuration(subject: webDomain.domain)
    }
}
