import Foundation
import SwiftUI

/// Idiomas soportados
enum Language: String, CaseIterable {
    case spanish = "es"
    case galician = "gl"

    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .galician: return "Galego"
        }
    }

    var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .galician: return "🏴"
        }
    }
}

/// Keys de localización
enum LocalizedKey: String {
    // MARK: - General
    case appName = "app.name"
    case cancel = "general.cancel"
    case save = "general.save"
    case ok = "general.ok"
    case send = "general.send"
    case next = "general.next"
    case skip = "general.skip"
    case start = "general.start"
    case loading = "general.loading"
    case error = "general.error"
    case success = "general.success"

    // MARK: - Onboarding
    case onboardingWelcomeTitle = "onboarding.welcome.title"
    case onboardingWelcomeMessage = "onboarding.welcome.message"
    case onboardingMissionsTitle = "onboarding.missions.title"
    case onboardingMissionsBullet1 = "onboarding.missions.bullet1"
    case onboardingMissionsBullet2 = "onboarding.missions.bullet2"
    case onboardingMissionsBullet3 = "onboarding.missions.bullet3"
    case onboardingAutoCheckinTitle = "onboarding.autocheckin.title"
    case onboardingAutoCheckinMessage = "onboarding.autocheckin.message"
    case onboardingAutoCheckinBullet1 = "onboarding.autocheckin.bullet1"
    case onboardingAutoCheckinBullet2 = "onboarding.autocheckin.bullet2"
    case onboardingAutoCheckinBullet3 = "onboarding.autocheckin.bullet3"
    case onboardingAutoCheckinBullet4 = "onboarding.autocheckin.bullet4"
    case onboardingNotificationsTitle = "onboarding.notifications.title"
    case onboardingNotificationsMessage = "onboarding.notifications.message"
    case onboardingNotificationsButton = "onboarding.notifications.button"
    case onboardingLocationTitle = "onboarding.location.title"
    case onboardingLocationMessage = "onboarding.location.message"
    case onboardingLocationButton = "onboarding.location.button"
    case onboardingPermissionsGranted = "onboarding.permissions.granted"
    case onboardingPermissionsDenied = "onboarding.permissions.denied"
    case onboardingPermissionsNotDetermined = "onboarding.permissions.notdetermined"
    case onboardingPermissionsUnknown = "onboarding.permissions.unknown"
    case onboardingLocationServicesDisabled = "onboarding.location.services.disabled"
    case onboardingOpenSettings = "onboarding.open.settings"
    case onboardingSettingsTitle = "onboarding.settings.title"
    case onboardingSettingsLanguage = "onboarding.settings.language"
    case onboardingSettingsTheme = "onboarding.settings.theme"
    case onboardingFeaturesTitle = "onboarding.features.title"
    case onboardingFeaturesBullet1 = "onboarding.features.bullet1"
    case onboardingFeaturesBullet2 = "onboarding.features.bullet2"
    case onboardingFeaturesBullet3 = "onboarding.features.bullet3"
    case onboardingFeaturesBullet4 = "onboarding.features.bullet4"
    case onboardingPermissionsTitle = "onboarding.permissions.title"
    case onboardingPermissionsMessage = "onboarding.permissions.message"
    case onboardingAccountTitle = "onboarding.account.title"
    case onboardingAccountMessage = "onboarding.account.message"
    case onboardingAccountBullet1 = "onboarding.account.bullet1"
    case onboardingAccountBullet2 = "onboarding.account.bullet2"
    case onboardingAccountBullet3 = "onboarding.account.bullet3"
    case onboardingAccountCreateButton = "onboarding.account.create"
    case onboardingAccountSkip = "onboarding.account.skip"
    case onboardingAccountCreating = "onboarding.account.creating"
    case onboardingAccountSuccess = "onboarding.account.success"
    case onboardingAccountSuccessMessage = "onboarding.account.success.message"

    // MARK: - Auth
    case loginTitle = "auth.login.title"
    case loginSubtitle = "auth.login.subtitle"
    case loginEmail = "auth.login.email"
    case loginEmailPlaceholder = "auth.login.email.placeholder"
    case loginPassword = "auth.login.password"
    case loginButton = "auth.login.button"
    case loginLoading = "auth.login.loading"
    case loginForgotPassword = "auth.login.forgot"
    case loginNoAccount = "auth.login.noaccount"
    case loginCreateAccount = "auth.login.create"
    case loginError = "auth.login.error"
    case loginErrorInvalidCredentials = "auth.login.error.credentials"
    case loginErrorEmailNotConfirmed = "auth.login.error.unconfirmed"
    case loginErrorRateLimit = "auth.login.error.ratelimit"
    case loginErrorNetwork = "auth.login.error.network"
    case loginErrorGeneric = "auth.login.error.generic"

    case registerTitle = "auth.register.title"
    case registerSubtitle = "auth.register.subtitle"
    case registerName = "auth.register.name"
    case registerNamePlaceholder = "auth.register.name.placeholder"
    case registerSurname = "auth.register.surname"
    case registerSurnamePlaceholder = "auth.register.surname.placeholder"
    case registerProfilePhoto = "auth.register.photo"
    case registerSelectPhoto = "auth.register.selectphoto"
    case registerChangePhoto = "auth.register.changephoto"
    case registerDeletePhoto = "auth.register.deletephoto"
    case registerButton = "auth.register.button"
    case registerLoading = "auth.register.loading"
    case registerPasswordHint = "auth.register.password.hint"
    case registerNavTitle = "auth.register.navtitle"
    case registerSuccessTitle = "auth.register.success.title"
    case registerSuccessMessage = "auth.register.success.message"
    case registerErrorAllFields = "auth.register.error.allfields"
    case registerErrorInvalidEmail = "auth.register.error.invalidemail"
    case registerErrorPasswordShort = "auth.register.error.password.short"
    case registerErrorPasswordUppercase = "auth.register.error.password.uppercase"
    case registerErrorPasswordLowercase = "auth.register.error.password.lowercase"
    case registerErrorPasswordNumber = "auth.register.error.password.number"
    case registerErrorAlreadyExists = "auth.register.error.exists"
    case registerErrorInvalidEmailFormat = "auth.register.error.invalidemail.format"
    case registerErrorRateLimit = "auth.register.error.ratelimit"
    case registerErrorProfile = "auth.register.error.profile"
    case registerErrorDuplicate = "auth.register.error.duplicate"
    case registerErrorGeneral = "auth.register.error.general"

    // MARK: - Campo Detail
    case campoLoading = "campo.loading"
    case campoNoCoordinates = "campo.no.coordinates"
    case campoLocationDenied = "campo.location.denied"
    case campoLocationNeeded = "campo.location.needed"
    case campoLocationError = "campo.location.error"
    case campoGPSWeak = "campo.gps.weak"
    case campoTooFar = "campo.too.far"
    case campoVisitSuccess = "campo.visit.success"
    case campoVisitSuccessTitle = "campo.visit.success.title"
    case campoVisitError = "campo.visit.error"
    case campoVisitErrorTitle = "campo.visit.error.title"
    case campoUnvisitSuccess = "campo.unvisit.success"
    case campoUnvisitError = "campo.unvisit.error"
    case campoDefaultName = "campo.default.name"

    // MARK: - Logros
    case logrosTitle = "logros.title"
    case logrosPending = "logros.pending"
    case logrosCompleted = "logros.completed"
    case logrosLoading = "logros.loading"
    case logrosAllCompleted = "logros.all.completed"
    case logrosAllCompletedMessage = "logros.all.completed.message"
    case logrosNone = "logros.none"
    case logrosNoneMessage = "logros.none.message"
    case logrosProgressTitle = "logros.progress.title"
    case logrosProgressCampos = "logros.progress.campos"
    case logrosProgressProvincias = "logros.progress.provincias"
    case logrosProgressRacha = "logros.progress.racha"
    case logrosProgressReviews = "logros.progress.reviews"
    case logrosCamposVisitados = "logros.campos.visitados"
    case logrosRachasDiarias = "logros.rachas.diarias"
    case logrosReseñas = "logros.reseñas"
    case logrosOtros = "logros.otros"

    // MARK: - Daily Reward
    case dailyRewardTitle = "daily.reward.title"
    case dailyRewardClaimed = "daily.reward.claimed"
    case dailyRewardClaim = "daily.reward.claim"
    case dailyRewardDay = "daily.reward.day"
    case dailyRewardStreak = "daily.reward.streak"
    case dailyRewardProcessing = "daily.reward.processing"
    case dailyRewardNotificationTitle = "daily.reward.notification.title"
    case dailyRewardNotificationBody = "daily.reward.notification.body"
    case dailyStreakWarningBody = "daily.streak.warning.body"
    case logrosStreakCurrent = "logros.streak.current"
    case logrosStreakWeeklyCycle = "logros.streak.weekly.cycle"
    case logrosStreakDaysSingular = "logros.streak.days.singular"
    case logrosStreakDaysPlural = "logros.streak.days.plural"
    case logrosMasterName = "logros.master.name"
    case logrosMasterDesc = "logros.master.desc"
    case logrosMasterToast = "logros.master.toast"

    // MARK: - Notifications
    case notifDisabledTitle = "notif.disabled.title"
    case notifDisabledMessage = "notif.disabled.message"
    case notifGoToSettings = "notif.go.settings"
    case notifAutoCheckinTitle = "notif.autocheckin.title"
    case notifAutoCheckinBody = "notif.autocheckin.body"
    case notifAutoCheckinErrorTitle = "notif.autocheckin.error.title"
    case notifAutoCheckinErrorBody = "notif.autocheckin.error.body"

    // MARK: - Reviews
    case reviewAdd = "review.add"
    case reviewEdit = "review.edit"
    case reviewYourRating = "review.your.rating"
    case reviewYourOpinion = "review.your.opinion"
    case reviewPlaceholder = "review.placeholder"
    case reviewGuidelines = "review.guidelines"
    case reviewPhotosOptional = "review.photos.optional"
    case reviewPhotosHelp = "review.photos.help"
    case reviewAnonymous = "review.anonymous"
    case reviewAnonymousHelp = "review.anonymous.help"
    case reviewPublish = "review.publish"
    case reviewPublishing = "review.publishing"
    case reviewUpdating = "review.updating"
    case reviewPublished = "review.published"
    case reviewUpdated = "review.updated"
    case reviewRatingVeryBad = "review.rating.verybad"
    case reviewRatingBad = "review.rating.bad"
    case reviewRatingRegular = "review.rating.regular"
    case reviewRatingGood = "review.rating.good"
    case reviewRatingExcellent = "review.rating.excellent"

    // MARK: - Contribuciones
    case contribucionTitle = "contribucion.title"
    case contribucionHelp = "contribucion.help"
    case contribucionAddPhotos = "contribucion.add.photos"
    case contribucionCantina = "contribucion.cantina"
    case contribucionAforo = "contribucion.aforo"
    case contribucionMedidas = "contribucion.medidas"
    case contribucionIluminacion = "contribucion.iluminacion"
    case contribucionIluminacionNatural = "contribucion.iluminacion.natural"
    case contribucionIluminacionArtificial = "contribucion.iluminacion.artificial"
    case contribucionCesped = "contribucion.cesped"
    case contribucionCespedBueno = "contribucion.cesped.bueno"
    case contribucionCespedRegular = "contribucion.cesped.regular"
    case contribucionCespedMalo = "contribucion.cesped.malo"
    case contribucionAccesibilidad = "contribucion.accesibilidad"
    case contribucionAccesibilidadSi = "contribucion.accesibilidad.si"
    case contribucionAccesibilidadNo = "contribucion.accesibilidad.no"
    case contribucionParking = "contribucion.parking"
    case contribucionSuccess = "contribucion.success"
    case contribucionError = "contribucion.error"
    case contribucionSelect = "contribucion.select"

    // MARK: - Toast Messages
    case toastVisited = "toast.visited"
    case toastUnvisited = "toast.unvisited"
    case toastXPGained = "toast.xp.gained"
    case toastLevelUp = "toast.levelup"
    case toastAchievement = "toast.achievement"

    // MARK: - Profile
    case profileLanguage = "profile.language"
    case profileLanguageTitle = "profile.language.title"
    case profileLanguageMessage = "profile.language.message"

    // MARK: - Empty States
    case emptyNoData = "empty.nodata"

    // MARK: - Loading Messages
    case loadingCampos = "loading.campos"

    // MARK: - ContentView
    case contentHome = "content.home"
    case contentShownFields = "content.shown.fields"
    case contentAllProvinces = "content.all.provinces"
    case contentFilterLabel = "content.filter.label"
    case contentSearchByName = "content.search.name"
    case contentSearchByLocation = "content.search.location"
    case contentProvince = "content.province"
    case contentApply = "content.apply"
    case contentReset = "content.reset"
    case loadingCampoInfo = "loading.campo.info"
    case loadingLogros = "loading.logros"
    case loadingLocation = "loading.location"

    // MARK: - Map View
    case mapSearchPlaceholder = "map.search.placeholder"
    case mapContinueStraight = "map.continue.straight"
    case mapDestination = "map.destination"
    case mapKilometers = "map.kilometers"
    case mapMinutesApprox = "map.minutes.approx"
    case mapStartNavigation = "map.start.navigation"
    case mapFootballField = "map.football.field"
    case mapOf = "map.of"

    // MARK: - Nearby Campos
    case nearbyCamposTitle = "nearby.campos.title"
    case nearbyMaxDistance = "nearby.max.distance"
    case nearbyNoFieldsFound = "nearby.no.fields.found"
    case nearbyLocationError = "nearby.location.error"
    case nearbyDistance = "nearby.distance"

    // MARK: - Profile
    case profileTitle = "profile.title"
    case profileHello = "profile.hello"
    case profileLevel = "profile.level"
    case profileAutoCheckin = "profile.auto.checkin"
    case profileAutoCheckinDesc = "profile.auto.checkin.desc"
    case profileAutoCheckinWarning = "profile.auto.checkin.warning"
    case profilePersonalInfo = "profile.personal.info"
    case profileEdit = "profile.edit"
    case profileName = "profile.name"
    case profileSurname = "profile.surname"
    case profileEmail = "profile.email"
    case profileNotAvailable = "profile.not.available"
    case profileLogout = "profile.logout"
    case profileAutoCheckinInfoTitle = "profile.auto.checkin.info.title"
    case profileAutoCheckinInfoDesc = "profile.auto.checkin.info.desc"
    case profileAutoCheckinInfoHow = "profile.auto.checkin.info.how"
    case profileAutoCheckinInfoDetect = "profile.auto.checkin.info.detect"
    case profileAutoCheckinInfoWait = "profile.auto.checkin.info.wait"
    case profileAutoCheckinInfoRegister = "profile.auto.checkin.info.register"
    case profileAutoCheckinInfoNoRepeat = "profile.auto.checkin.info.norepeat"
    case profileAutoCheckinInfoReqs = "profile.auto.checkin.info.reqs"
    case profileAutoCheckinInfoReqAlways = "profile.auto.checkin.info.req.always"
    case profileAutoCheckinInfoReqBackground = "profile.auto.checkin.info.req.background"
    case profileAutoCheckinInfoReqInternet = "profile.auto.checkin.info.req.internet"
    case profileClose = "profile.close"

    // MARK: - Levels Info
    case levelsTitle = "levels.title"
    case levelsInfoTitle = "levels.info.title"
    case levelsWhatFor = "levels.what.for"
    case levelsBenefitVisibility = "levels.benefit.visibility"
    case levelsBenefitRecognition = "levels.benefit.recognition"
    case levelsBenefitProgress = "levels.benefit.progress"
    case levelsBenefitUnlock = "levels.benefit.unlock"
    case levelsHowToGetXP = "levels.how.to.get.xp"
    case levelsVisitFields = "levels.visit.fields"
    case levelsVisitFieldsDesc = "levels.visit.fields.desc"
    case levelsVariable = "levels.variable"
    case levelsWriteReviews = "levels.write.reviews"
    case levelsWriteReviewsDesc = "levels.write.reviews.desc"
    case levelsReviewBase = "levels.review.base"
    case levelsReviewDetailed = "levels.review.detailed"
    case levelsReviewPhotos = "levels.review.photos"
    case levelsReviewEdited = "levels.review.edited"
    case levelsDailyReward = "levels.daily.reward"
    case levelsDailyRewardDesc = "levels.daily.reward.desc"
    case levelsDailyDay = "levels.daily.day"
    case levelsUnlockAchievements = "levels.unlock.achievements"
    case levelsUnlockAchievementsDesc = "levels.unlock.achievements.desc"
    case levelsAchievementFields = "levels.achievement.fields"
    case levelsAchievementStreaks = "levels.achievement.streaks"
    case levelsAchievementReviews = "levels.achievement.reviews"
    case levelsAndMore = "levels.and.more"
    case levelsBenefitsTitle = "levels.benefits.title"
    case levelsBenefitsDesc = "levels.benefits.desc"
    case levelsTotal = "levels.total"

    // MARK: - Edit Profile
    case editProfileTitle = "edit.profile.title"
    case editProfileAddPhoto = "edit.profile.add.photo"
    case editProfileChangePhoto = "edit.profile.change.photo"
    case editProfileDeletePhoto = "edit.profile.delete.photo"
    case editProfilePhotoSection = "edit.profile.photo.section"
    case editProfilePersonalInfo = "edit.profile.personal.info"
    case editProfileNamePlaceholder = "edit.profile.name.placeholder"
    case editProfileSurnamePlaceholder = "edit.profile.surname.placeholder"
    case editProfileEmailSection = "edit.profile.email.section"
    case editProfileEmailPlaceholder = "edit.profile.email.placeholder"
    case editProfileRequestEmailChange = "edit.profile.request.email.change"
    case editProfileEmailChangeFooter = "edit.profile.email.change.footer"
    case editProfileEmailChangeWarning = "edit.profile.email.change.warning"
    case editProfilePasswordSection = "edit.profile.password.section"
    case editProfileChangePassword = "edit.profile.change.password"
    case editProfilePasswordFooter = "edit.profile.password.footer"
    case editProfileNewPassword = "edit.profile.new.password"
    case editProfileConfirmPassword = "edit.profile.confirm.password"
    case editProfileSavingChanges = "edit.profile.saving.changes"
    case editProfileSaveChanges = "edit.profile.save.changes"
    case editProfileDeletePhotoConfirm = "edit.profile.delete.photo.confirm"
    case editProfilePasswordStrength = "edit.profile.password.strength"

    // MARK: - Password Reset
    case passwordResetTitle = "password.reset.title"
    case passwordResetDesc = "password.reset.desc"
    case passwordResetEmailPlaceholder = "password.reset.email.placeholder"
    case passwordResetButton = "password.reset.button"
    case passwordResetSending = "password.reset.sending"
    case passwordResetSuccess = "password.reset.success"
    case passwordResetBackToLogin = "password.reset.back.to.login"
    case passwordResetResendIn = "password.reset.resend.in"
    case passwordResetInvalidEmail = "password.reset.invalid.email"
    case passwordResetError = "password.reset.error"
    case passwordResetErrorRateLimit = "password.reset.error.rate.limit"
    case passwordResetErrorNetwork = "password.reset.error.network"
    case passwordResetErrorGeneric = "password.reset.error.generic"
    case passwordResetNewTitle = "password.reset.new.title"
    case passwordResetNewDesc = "password.reset.new.desc"
    case passwordResetNewButton = "password.reset.new.button"
    case passwordResetNewSuccess = "password.reset.new.success"
    case passwordResetNewError = "password.reset.new.error"
    case passwordResetNewMismatch = "password.reset.new.mismatch"
    case passwordResetNewErrorSamePassword = "password.reset.new.error.same"
    case passwordResetNewErrorShort = "password.reset.new.error.short"
    case passwordResetNewErrorWeak = "password.reset.new.error.weak"
    case passwordResetNewErrorExpired = "password.reset.new.error.expired"
    case passwordResetNewErrorSession = "password.reset.new.error.session"
    case passwordResetNewErrorNetwork = "password.reset.new.error.network"
    case passwordResetNewErrorGeneric = "password.reset.new.error.generic"

    // MARK: - Navigation Tabs
    case tabHome = "tab.home"
    case tabMap = "tab.map"
    case tabNearby = "tab.nearby"
    case tabProfile = "tab.profile"

    // MARK: - Navigation Alerts
    case navRouteInProgress = "nav.route.in.progress"
    case navContinueRoute = "nav.continue.route"
    case navStopAndExit = "nav.stop.and.exit"
    case navCancelMessage = "nav.cancel.message"
    case navVerification = "nav.verification"
    case navVerificationSuccess = "nav.verification.success"
    case navVerificationError = "nav.verification.error"
    case navAccept = "nav.accept"

    // MARK: - Campo Sections
    case campoPhotos = "campo.photos"
    case campoPhotoBy = "campo.photo.by"
    case campoDetails = "campo.details"
    case campoLocation = "campo.location"
    case campoHowToGet = "campo.how.to.get"
    case campoContribute = "campo.contribute"
    case campoUnknownUser = "campo.unknown.user"

    // MARK: - Review Actions
    case reviewEditAction = "review.edit.action"
    case reviewDeleteAction = "review.delete.action"
    case reviewWriteNew = "review.write.new"
    case reviewsAndRatings = "reviews.and.ratings"
    case reviewLoadError = "review.load.error"
    case reviewAddPhotosCount = "review.add.photos.count"

    // MARK: - Preferences
    case preferencesTitle = "preferences.title"

    // MARK: - Review Stats
    case reviewRating = "review.rating"
    case reviewRatings = "review.ratings"
    case reviewNoRatingsYet = "review.no.ratings.yet"
    case reviewEditMine = "review.edit.mine"
    case reviewSingle = "review.single"
    case reviewPlural = "review.plural"
    case reviewNoReviewsYet = "review.no.reviews.yet"
    case reviewBeFirst = "review.be.first"
    case reviewEdited = "review.edited"
    case reviewEditedAt = "review.edited.at"
    case reviewOf = "review.of"
    case reviewLoginToOpine = "review.login.to.opine"
    case reviewShareExperience = "review.share.experience"
    case reviewVisitFirst = "review.visit.first"
    case reviewOnlyVisited = "review.only.visited"
    case reviewAlreadyLeft = "review.already.left"
    case reviewOnlyOne = "review.only.one"
    case reviewRetry = "review.retry"
    case reviewCompleted = "review.completed"

    // MARK: - Daily Reward Extra
    case dailyRewardClaimedToday = "daily.reward.claimed.today"
    case dailyRewardTestNotif = "daily.reward.test.notif"

    // MARK: - Preferences Extra
    case preferencesDistance = "preferences.distance"
    case preferencesDistanceKm = "preferences.distance.km"

    // MARK: - Profile Stats
    case profileStats = "profile.stats"
    case profileVisitHistory = "profile.visit.history"
    case profileNoVisitsYet = "profile.no.visits.yet"

    // MARK: - Provinces
    case provinceACoruna = "province.a.coruna"
    case provinceOurense = "province.ourense"
    case provinceLugo = "province.lugo"
    case provincePontevedra = "province.pontevedra"

    // MARK: - Test Notifications
    case testNotificationTitle = "test.notification.title"
    case testNotificationBody = "test.notification.body"

    // MARK: - Configuration Errors
    case errorSupabaseCredentials = "error.supabase.credentials"
    case errorSupabaseInvalidURL = "error.supabase.invalid.url"

    // MARK: - Authentication Errors
    case errorUserNotAuthenticated = "error.user.not.authenticated"
    case errorCouldNotAuthenticate = "error.could.not.authenticate"

    // MARK: - Review Sort Types
    case reviewSortRecent = "review.sort.recent"
    case reviewSortOldest = "review.sort.oldest"
    case reviewSortHighest = "review.sort.highest"
    case reviewSortLowest = "review.sort.lowest"

    // MARK: - Review Manager Errors
    case errorLoadingReviews = "error.loading.reviews"
    case errorCouldNotUpdateReview = "error.could.not.update.review"
    case errorUpdatingReview = "error.updating.review"
    case errorDeletingReview = "error.deleting.review"

    // MARK: - Profile Errors
    case errorMultiplePreferences = "error.multiple.preferences"
    case errorLogout = "error.logout"

    // MARK: - Success Messages
    case successPreferencesSaved = "success.preferences.saved"

    // MARK: - UI Elements
    case reviewAnonymousName = "review.anonymous.name"
    case reviewShowLess = "review.show.less"
    case reviewShowMore = "review.show.more"
    case preferencesButtonSaving = "preferences.button.saving"
    case preferencesButtonSave = "preferences.button.save"
    case reviewRatingLabel = "review.rating.label"

    // MARK: - Connection Status
    case connectionTypeCellular = "connection.type.cellular"
    case connectionTypeUnknown = "connection.type.unknown"
    case connectionOffline = "connection.offline"

    // MARK: - Settings
    case settingsTitle = "settings.title"
    case settingsGeneral = "settings.general"
    case settingsAccount = "settings.account"
    case settingsTheme = "settings.theme"
    case settingsThemeLight = "settings.theme.light"
    case settingsThemeDark = "settings.theme.dark"
    case settingsThemeSystem = "settings.theme.system"

    // MARK: - Detail Views
    case reviewDetailTitle = "review.detail.title"
    case logrosDetailTitle = "logros.detail.title"
    case logrosDetailCompleted = "logros.detail.completed"
    case logrosDetailProgress = "logros.detail.progress"
    case reviewDeleteConfirmTitle = "review.delete.confirm.title"
    case reviewDeleteConfirmMessage = "review.delete.confirm.message"

    // MARK: - Legal / Info section
    case settingsInfo = "settings.info"
    case settingsTerms = "settings.terms"
    case settingsContact = "settings.contact"
    case settingsSuggest = "settings.suggest"

    // MARK: - Términos y Condiciones
    case termsTitle = "terms.title"
    case termsLastUpdated = "terms.last.updated"
    case termsSection1Title = "terms.section1.title"
    case termsSection1Body = "terms.section1.body"
    case termsSection2Title = "terms.section2.title"
    case termsSection2Body = "terms.section2.body"
    case termsSection3Title = "terms.section3.title"
    case termsSection3Body = "terms.section3.body"
    case termsSection4Title = "terms.section4.title"
    case termsSection4Body = "terms.section4.body"
    case termsSection5Title = "terms.section5.title"
    case termsSection5Body = "terms.section5.body"
    case termsSection6Title = "terms.section6.title"
    case termsSection6Body = "terms.section6.body"

    // MARK: - Contacto
    case contactTitle = "contact.title"
    case contactSubtitle = "contact.subtitle"
    case contactEmailLabel = "contact.email.label"
    case contactEmailAction = "contact.email.action"
    case contactSuggestHint = "contact.suggest.hint"

    // MARK: - Sugerir Campo
    case suggestTitle = "suggest.title"
    case suggestSubtitle = "suggest.subtitle"
    case suggestFieldName = "suggest.field.name"
    case suggestFieldNamePlaceholder = "suggest.field.name.placeholder"
    case suggestMunicipality = "suggest.municipality"
    case suggestMunicipalityPlaceholder = "suggest.municipality.placeholder"
    case suggestProvince = "suggest.province"
    case suggestNotes = "suggest.notes"
    case suggestNotesPlaceholder = "suggest.notes.placeholder"
    case suggestSend = "suggest.send"
    case suggestSending = "suggest.sending"
    case suggestSuccessTitle = "suggest.success.title"
    case suggestSuccessMessage = "suggest.success.message"
    case suggestErrorEmpty = "suggest.error.empty"
    case suggestErrorGeneral = "suggest.error.general"
    case suggestLoginRequired = "suggest.login.required"
    case suggestLoginRequiredMessage = "suggest.login.required.message"
    case suggestAnotherOne = "suggest.another.one"
}

/// Manager de localización centralizado
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            objectWillChange.send()
        }
    }

    private init() {
        let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? Language.spanish.rawValue
        self.currentLanguage = Language(rawValue: savedLang) ?? .spanish
    }

    /// Obtiene la traducción para una key
    nonisolated func localized(_ key: LocalizedKey, _ args: CVarArg...) -> String {
        // Leer idioma actual desde UserDefaults (thread-safe)
        let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? Language.spanish.rawValue
        let currentLang = Language(rawValue: savedLang) ?? .spanish

        let format = translations[currentLang]?[key] ?? key.rawValue
        if args.isEmpty {
            return format
        }
        return String(format: format, arguments: args)
    }

    /// Mapea un error de inicio de sesión (Supabase) a un mensaje localizado
    nonisolated func mapLoginError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        let key: LocalizedKey
        if msg.contains("invalid login credentials") || msg.contains("invalid email or password")
            || msg.contains("wrong password") || msg.contains("invalid credentials")
            || msg.contains("email not found") || msg.contains("user not found") {
            key = .loginErrorInvalidCredentials
        } else if msg.contains("email not confirmed") || msg.contains("confirm your email")
            || msg.contains("not verified") {
            key = .loginErrorEmailNotConfirmed
        } else if msg.contains("rate limit") || msg.contains("too many requests") {
            key = .loginErrorRateLimit
        } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
            key = .loginErrorNetwork
        } else {
            key = .loginErrorGeneric
        }
        return localized(key)
    }

    /// Mapea un error de registro (Supabase) a un mensaje localizado
    nonisolated func mapRegisterError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        let key: LocalizedKey
        if msg.contains("user already registered") || msg.contains("already registered")
            || (msg.contains("email") && msg.contains("exists")) {
            key = .registerErrorAlreadyExists
        } else if msg.contains("invalid email") || (msg.contains("email") && msg.contains("invalid")) {
            key = .registerErrorInvalidEmailFormat
        } else if msg.contains("password") && (msg.contains("short") || msg.contains("length")) {
            key = .registerErrorPasswordShort
        } else if msg.contains("rate limit") || msg.contains("too many requests") {
            key = .registerErrorRateLimit
        } else if msg.contains("foreign key") || msg.contains("perfiles_id_fkey") {
            key = .registerErrorProfile
        } else if msg.contains("duplicate key") || msg.contains("conflict") {
            key = .registerErrorDuplicate
        } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
            key = .loginErrorNetwork
        } else {
            key = .registerErrorGeneral
        }
        return localized(key)
    }

    /// Mapea un error de actualización de contraseña (Supabase) a una key localizada
    nonisolated func mapPasswordUpdateError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        let key: LocalizedKey
        if msg.contains("password") && (msg.contains("short") || msg.contains("length") || msg.contains("characters")) {
            key = .passwordResetNewErrorShort
        } else if msg.contains("same password")
            || msg.contains("different from the old password")
            || msg.contains("should be different")
            || (msg.contains("new password") && msg.contains("different"))
            || (msg.contains("password") && msg.contains("same")) {
            key = .passwordResetNewErrorSamePassword
        } else if msg.contains("weak password") || msg.contains("password strength") {
            key = .passwordResetNewErrorWeak
        } else if msg.contains("expired") || msg.contains("invalid token") {
            key = .passwordResetNewErrorExpired
        } else if msg.contains("not authenticated") || msg.contains("unauthorized") || msg.contains("session") {
            key = .passwordResetNewErrorSession
        } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
            key = .passwordResetNewErrorNetwork
        } else {
            key = .passwordResetNewErrorGeneric
        }
        return localized(key)
    }

    /// Mapea un error de envío de correo de recuperación (Supabase) a una key localizada
    nonisolated func mapPasswordResetEmailError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        let key: LocalizedKey
        if msg.contains("invalid email") || (msg.contains("email") && msg.contains("invalid")) {
            key = .passwordResetInvalidEmail
        } else if msg.contains("rate limit") || msg.contains("too many requests") || msg.contains("email rate limit") {
            key = .passwordResetErrorRateLimit
        } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
            key = .passwordResetErrorNetwork
        } else {
            key = .passwordResetErrorGeneric
        }
        return localized(key)
    }

    /// Diccionario de traducciones
    let translations: [Language: [LocalizedKey: String]] = [
        // MARK: - Español
        .spanish: [
            // General
            .appName: "Campos de Galicia",
            .cancel: "Cancelar",
            .save: "Guardar",
            .ok: "OK",
            .send: "Enviar",
            .next: "Siguiente",
            .skip: "Saltar",
            .start: "Empezar",
            .loading: "Cargando...",
            .error: "Error",
            .success: "Éxito",

            // Onboarding
            .onboardingWelcomeTitle: "¡Bienvenido a Campos de Galicia!",
            .onboardingWelcomeMessage: "Descubre los campos de fútbol de toda Galicia. Visita, explora y colecciona ubicaciones reales mientras ganas XP.",
            .onboardingMissionsTitle: "Misiones y XP",
            .onboardingMissionsBullet1: "Marca campos como visitados cuando estés cerca del campo (200m).",
            .onboardingMissionsBullet2: "Completa misiones visitando campos y manteniendo rachas diarias.",
            .onboardingMissionsBullet3: "Gana XP y sube de nivel. ¡Explora Galicia y progresa!",
            .onboardingAutoCheckinTitle: "Auto Check-in",
            .onboardingAutoCheckinMessage: "El auto check-in registra tu visita automáticamente cuando estés cerca de un campo (200m) y permanezcas allí 2 minutos.",
            .onboardingAutoCheckinBullet1: "Funciona en segundo plano con muy bajo consumo de batería.",
            .onboardingAutoCheckinBullet2: "No rastrea tu ubicación constantemente.",
            .onboardingAutoCheckinBullet3: "Requiere permanencia de 2 minutos en el área.",
            .onboardingAutoCheckinBullet4: "Solo se registra una vez por campo.",
            .onboardingNotificationsTitle: "Notificaciones",
            .onboardingNotificationsMessage: "Te avisaremos cuando tu recompensa diaria esté lista y cuando visites un campo automáticamente.",
            .onboardingNotificationsButton: "Permitir Notificaciones",
            .onboardingLocationTitle: "Permitir ubicación",
            .onboardingLocationMessage: "Necesitamos tu ubicación solo para verificar que visitas los campos de verdad y registrar tus logros.",
            .onboardingLocationButton: "Permitir Ubicación",
            .onboardingPermissionsGranted: "Permisos otorgados",
            .onboardingPermissionsDenied: "Permisos denegados",
            .onboardingPermissionsNotDetermined: "Permiso no determinado",
            .onboardingPermissionsUnknown: "Estado desconocido",
            .onboardingLocationServicesDisabled: "Servicios de localización desactivados",
            .onboardingOpenSettings: "Abrir Ajustes",
            .onboardingSettingsTitle: "Personaliza tu experiencia",
            .onboardingSettingsLanguage: "Idioma",
            .onboardingSettingsTheme: "Apariencia",
            .onboardingFeaturesTitle: "Cómo funciona",
            .onboardingFeaturesBullet1: "Visita campos reales y regístralos automáticamente al estar cerca.",
            .onboardingFeaturesBullet2: "Completa logros, mantén rachas y sube de nivel.",
            .onboardingFeaturesBullet3: "Escribe reseñas y comparte tu experiencia.",
            .onboardingFeaturesBullet4: "Explora el mapa y descubre campos cerca de ti.",
            .onboardingPermissionsTitle: "Permisos necesarios",
            .onboardingPermissionsMessage: "Para registrar tus visitas automáticamente necesitamos acceso a tu ubicación y notificaciones.",
            .onboardingAccountTitle: "Crea tu cuenta",
            .onboardingAccountMessage: "Con una cuenta podrás acceder a todas las funcionalidades:",
            .onboardingAccountBullet1: "Guardar tus visitas y progreso.",
            .onboardingAccountBullet2: "Desbloquear logros y ganar XP.",
            .onboardingAccountBullet3: "Escribir reseñas y participar en la comunidad.",
            .onboardingAccountCreateButton: "Crear cuenta",
            .onboardingAccountSkip: "Continuar sin cuenta",
            .onboardingAccountCreating: "Creando cuenta...",
            .onboardingAccountSuccess: "¡Cuenta creada!",
            .onboardingAccountSuccessMessage: "Ya puedes disfrutar de todas las funcionalidades.",

            // Auth
            .loginTitle: "Campos de Galicia",
            .loginSubtitle: "Descubre los campos de fútbol de Galicia",
            .loginEmail: "Correo Electrónico",
            .loginEmailPlaceholder: "tu@email.com",
            .loginPassword: "Contraseña",
            .loginButton: "Iniciar Sesión",
            .loginLoading: "Iniciando sesión...",
            .loginForgotPassword: "¿Olvidaste tu contraseña?",
            .loginNoAccount: "¿No tienes cuenta?",
            .loginCreateAccount: "Crear cuenta",
            .loginError: "Error al iniciar sesión: %@",
            .loginErrorInvalidCredentials: "Email o contraseña incorrectos.",
            .loginErrorEmailNotConfirmed: "Debes verificar tu correo electrónico antes de iniciar sesión.",
            .loginErrorRateLimit: "Demasiados intentos. Espera unos minutos e inténtalo de nuevo.",
            .loginErrorNetwork: "Sin conexión a internet. Comprueba tu conexión e inténtalo de nuevo.",
            .loginErrorGeneric: "No hemos podido iniciar sesión. Inténtalo de nuevo más tarde.",

            .registerTitle: "Crear Cuenta",
            .registerSubtitle: "Únete a la comunidad de Campos de Galicia",
            .registerName: "Nombre",
            .registerNamePlaceholder: "Tu nombre",
            .registerSurname: "Apellidos",
            .registerSurnamePlaceholder: "Tus apellidos",
            .registerProfilePhoto: "Foto de perfil (opcional)",
            .registerSelectPhoto: "Seleccionar foto",
            .registerChangePhoto: "Cambiar foto",
            .registerDeletePhoto: "Eliminar",
            .registerButton: "Crear cuenta",
            .registerLoading: "Creando cuenta...",
            .registerPasswordHint: "Mínimo 8 caracteres, con mayúscula, minúscula y número",
            .registerNavTitle: "Registro",
            .registerSuccessTitle: "¡Registro Exitoso!",
            .registerSuccessMessage: "Tu cuenta ha sido creada. Por favor revisa tu correo para verificar tu cuenta.",
            .registerErrorAllFields: "Todos los campos son obligatorios.",
            .registerErrorInvalidEmail: "Introduce un correo electrónico válido.",
            .registerErrorPasswordShort: "La contraseña debe tener al menos 8 caracteres.",
            .registerErrorPasswordUppercase: "La contraseña debe contener al menos una letra mayúscula.",
            .registerErrorPasswordLowercase: "La contraseña debe contener al menos una letra minúscula.",
            .registerErrorPasswordNumber: "La contraseña debe contener al menos un número.",
            .registerErrorAlreadyExists: "Ese correo ya está registrado. Inicia sesión o usa '¿Olvidaste tu contraseña?'.",
            .registerErrorInvalidEmailFormat: "El correo no es válido. Revisa el formato (ej. usuario@dominio.com).",
            .registerErrorRateLimit: "Has hecho demasiadas solicitudes. Inténtalo de nuevo en unos minutos.",
            .registerErrorProfile: "Se produjo un problema al crear tu perfil. Vuelve a intentarlo en unos segundos.",
            .registerErrorDuplicate: "Ya existía un perfil asociado a este usuario. Inicia sesión con tu correo.",
            .registerErrorGeneral: "No hemos podido crear tu cuenta ahora mismo. Inténtalo de nuevo en unos minutos.",

            // Campo Detail
            .campoLoading: "Cargando información del campo...",
            .campoNoCoordinates: "Este campo aún no tiene coordenadas. Ayúdanos a añadirlas",
            .campoLocationDenied: "Activa la ubicación en: Ajustes → Privacidad y Seguridad → Ubicación → Campos de Galicia",
            .campoLocationNeeded: "Necesitamos permiso para acceder a tu ubicación",
            .campoLocationError: "No pudimos obtener tu ubicación. Asegúrate de estar en un lugar con buena señal GPS",
            .campoGPSWeak: "La señal GPS es débil (%dm de precisión). Sal al exterior para mejor precisión",
            .campoTooFar: "Estás a ~%@ del campo. Acércate más (necesitas estar a %@ o menos)",
            .campoVisitSuccess: "Has visitado %@",
            .campoVisitSuccessTitle: "✅ ¡Éxito!",
            .campoVisitError: "Error al registrar visita",
            .campoVisitErrorTitle: "No se pudo marcar la visita",
            .campoUnvisitSuccess: "Visita desmarcada",
            .campoUnvisitError: "Error al desmarcar visita",
            .campoDefaultName: "Campo",

            // Logros
            .logrosTitle: "Logros y Recompensas",
            .logrosPending: "Pendientes",
            .logrosCompleted: "Completados",
            .logrosLoading: "Cargando logros...",
            .logrosAllCompleted: "¡Enhorabuena! Completaste todos los logros.",
            .logrosAllCompletedMessage: "¡Eres un auténtico explorador de Galicia!",
            .logrosNone: "Aún no tienes logros",
            .logrosNoneMessage: "Visita campos, escribe reseñas y mantén rachas para desbloquear logros",
            .logrosProgressTitle: "Tu Progreso",
            .logrosProgressCampos: "Campos",
            .logrosProgressProvincias: "Provincias",
            .logrosProgressRacha: "Racha",
            .logrosProgressReviews: "Reseñas",
            .logrosCamposVisitados: "Campos visitados",
            .logrosRachasDiarias: "Rachas diarias",
            .logrosReseñas: "Reseñas",
            .logrosOtros: "Otros",

            // Daily Reward
            .dailyRewardTitle: "Recompensa Diaria",
            .dailyRewardClaimed: "¡Ya reclamaste hoy!",
            .dailyRewardClaim: "Reclamar +%d XP",
            .dailyRewardDay: "Día %d",
            .dailyRewardStreak: "racha",
            .dailyRewardProcessing: "Procesando...",
            .dailyRewardNotificationTitle: "Campos de Galicia",
            .dailyRewardNotificationBody: "¡Tu recompensa diaria te espera! Reclámala ahora en la sección de Logros 🎁",
            .dailyStreakWarningBody: "¡Tu racha de %d días está en peligro! Entra y reclama tu recompensa para no perderla 🔥",
            .logrosStreakCurrent: "racha actual",
            .logrosStreakWeeklyCycle: "ciclo semanal",
            .logrosStreakDaysSingular: "día",
            .logrosStreakDaysPlural: "días",
            .logrosMasterName: "Maestro de Campos",
            .logrosMasterDesc: "Has completado todos los logros. ¡Eres una leyenda!",
            .logrosMasterToast: "🏅 ¡Maestro de Campos! +%d XP",

            // Notifications
            .notifDisabledTitle: "Notificaciones desactivadas",
            .notifDisabledMessage: "Activa las notificaciones para recibir avisos cuando tu recompensa diaria esté lista y no perderte ningún día.",
            .notifGoToSettings: "Ir a Ajustes",
            .notifAutoCheckinTitle: "¡Campo visitado!",
            .notifAutoCheckinBody: "Has visitado %@. ¡Un campo más para tu colección! ⚽",
            .notifAutoCheckinErrorTitle: "No se pudo registrar la visita",
            .notifAutoCheckinErrorBody: "No pudimos registrar tu visita a %@. Revisa tu conexión e inténtalo de nuevo.",

            // Reviews
            .reviewAdd: "Nueva Reseña",
            .reviewEdit: "Editar Reseña",
            .reviewYourRating: "Tu valoración",
            .reviewYourOpinion: "Tu opinión",
            .reviewPlaceholder: "Cuéntanos tu experiencia en este campo...",
            .reviewGuidelines: "Sé respetuoso y describe tu experiencia de forma honesta.",
            .reviewPhotosOptional: "Fotos (opcional)",
            .reviewPhotosHelp: "Sube fotos del campo para ayudar a otros visitantes (máximo %d).",
            .reviewAnonymous: "Reseña anónima",
            .reviewAnonymousHelp: "Si activas esta opción, tu nombre no será visible en la reseña.",
            .reviewPublish: "Publicar",
            .reviewPublishing: "Publicando reseña...",
            .reviewUpdating: "Actualizando reseña...",
            .reviewPublished: "¡Reseña publicada!",
            .reviewUpdated: "¡Reseña actualizada!",
            .reviewRatingVeryBad: "😞 Muy malo",
            .reviewRatingBad: "😕 Malo",
            .reviewRatingRegular: "😐 Regular",
            .reviewRatingGood: "😊 Bueno",
            .reviewRatingExcellent: "🤩 Excelente",

            // Contribuciones
            .contribucionTitle: "Aportar información",
            .contribucionHelp: "Ayuda a completar los datos de %@",
            .contribucionAddPhotos: "Añadir fotos",
            .contribucionCantina: "¿Tiene cantina?",
            .contribucionAforo: "Aforo de la grada (número)",
            .contribucionMedidas: "Medidas del campo (ej. 105x68 metros)",
            .contribucionIluminacion: "Tipo de iluminación",
            .contribucionIluminacionNatural: "Natural",
            .contribucionIluminacionArtificial: "Artificial",
            .contribucionCesped: "Estado del césped",
            .contribucionCespedBueno: "Bueno",
            .contribucionCespedRegular: "Regular",
            .contribucionCespedMalo: "Malo",
            .contribucionAccesibilidad: "Accesibilidad",
            .contribucionAccesibilidadSi: "Sí, tiene acceso para discapacitados",
            .contribucionAccesibilidadNo: "No, no tiene acceso",
            .contribucionParking: "¿Tiene parking?",
            .contribucionSuccess: "✅ Contribución enviada. ¡Gracias!",
            .contribucionError: "Error al enviar contribución",
            .contribucionSelect: "Seleccionar",

            // Toast
            .toastVisited: "✅ ¡Visitado! %@",
            .toastUnvisited: "Visita desmarcada",
            .toastXPGained: "+%d XP - %@",
            .toastLevelUp: "⬆️ ¡Nivel %d alcanzado!",
            .toastAchievement: "🏆 ¡Nuevo logro! %@",

            // Profile
            .profileLanguage: "Idioma",
            .profileLanguageTitle: "Seleccionar idioma",
            .profileLanguageMessage: "Escoge el idioma de la aplicación",

            // Empty States
            .emptyNoData: "No hay datos disponibles",

            // Loading
            .loadingCampos: "Cargando campos de Galicia...",
            .loadingCampoInfo: "Cargando información del campo...",
            .loadingLogros: "Cargando logros...",
            .loadingLocation: "Obteniendo tu ubicación...",

            // ContentView
            .contentHome: "Inicio",
            .contentShownFields: "Mostrados %d campos",
            .contentAllProvinces: "Todas",
            .contentFilterLabel: "Filtrar:",
            .contentSearchByName: "Buscar campo o localidad...",
            .contentSearchByLocation: "Buscar por localidad",
            .contentProvince: "Provincia:",
            .contentApply: "Aplicar",
            .contentReset: "Resetear",

            // Map View
            .mapSearchPlaceholder: "Buscar campo...",
            .mapContinueStraight: "Continúa recto",
            .mapDestination: "Destino",
            .mapKilometers: "kilómetros",
            .mapMinutesApprox: "minutos aprox.",
            .mapStartNavigation: "Iniciar navegación",
            .mapFootballField: "Campo de fútbol",
            .mapOf: "de",

            // Nearby Campos
            .nearbyCamposTitle: "Campos cercanos",
            .nearbyMaxDistance: "Distancia máxima",
            .nearbyNoFieldsFound: "No se encontraron campos cercanos dentro de %d km.",
            .nearbyLocationError: "No se pudo obtener la ubicación. Habilita los servicios de ubicación.",
            .nearbyDistance: "Distancia: %.1f km",

            // Profile
            .profileTitle: "Perfil",
            .profileHello: "¡Hola, %@!",
            .profileLevel: "Nivel %d",
            .profileAutoCheckin: "Auto Check-in",
            .profileAutoCheckinDesc: "Registrar visitas automáticamente al estar 2 minutos cerca de un campo",
            .profileAutoCheckinWarning: "⚠️ Se necesitan permisos de ubicación 'Siempre' para el auto check-in",
            .profilePersonalInfo: "Información Personal",
            .profileEdit: "Editar",
            .profileName: "Nombre",
            .profileSurname: "Apellidos",
            .profileEmail: "Email",
            .profileNotAvailable: "No disponible",
            .profileLogout: "Cerrar Sesión",
            .profileAutoCheckinInfoTitle: "Auto Check-in",
            .profileAutoCheckinInfoDesc: "El auto check-in registra automáticamente tu visita cuando estás dentro de 200m de un campo y permaneces allí durante 2 minutos.",
            .profileAutoCheckinInfoHow: "Cómo funciona:",
            .profileAutoCheckinInfoDetect: "Detecta cuando entras en 200m de un campo",
            .profileAutoCheckinInfoWait: "Espera 2 minutos de permanencia en el área",
            .profileAutoCheckinInfoRegister: "Registra la visita automáticamente",
            .profileAutoCheckinInfoNoRepeat: "No se repite si ya visitaste el campo",
            .profileAutoCheckinInfoReqs: "Requisitos:",
            .profileAutoCheckinInfoReqAlways: "Permisos de ubicación 'Siempre'",
            .profileAutoCheckinInfoReqBackground: "Mantener la app en segundo plano",
            .profileAutoCheckinInfoReqInternet: "Conexión a internet para guardar",
            .profileClose: "Cerrar",

            // Levels Info
            .levelsTitle: "Niveles",
            .levelsInfoTitle: "Información sobre Niveles",
            .levelsWhatFor: "¿Para qué sirven los niveles?",
            .levelsBenefitVisibility: "Mayor visibilidad de tus reseñas",
            .levelsBenefitRecognition: "Reconocimiento dentro de la comunidad",
            .levelsBenefitProgress: "Seguimiento de tu progreso y dedicación",
            .levelsBenefitUnlock: "Desbloqueo de logros y recompensas",
            .levelsHowToGetXP: "¿Cómo conseguir XP?",
            .levelsVisitFields: "Visitar campos",
            .levelsVisitFieldsDesc: "Marca campos como visitados para ganar XP",
            .levelsVariable: "Variable",
            .levelsWriteReviews: "Escribir reseñas",
            .levelsWriteReviewsDesc: "Deja reseñas en campos visitados",
            .levelsReviewBase: "Base: 25 XP",
            .levelsReviewDetailed: "Reseña detallada (+100 caracteres): +10 XP",
            .levelsReviewPhotos: "Con fotos: +15 XP",
            .levelsReviewEdited: "Editada/mejorada: +5 XP",
            .levelsDailyReward: "Recompensa diaria",
            .levelsDailyRewardDesc: "Reclama tu recompensa cada día en la sección de Logros",
            .levelsDailyDay: "Día %d: %d XP",
            .levelsUnlockAchievements: "Desbloquear logros",
            .levelsUnlockAchievementsDesc: "Completa objetivos para ganar XP extra",
            .levelsAchievementFields: "Campos visitados: 50-500 XP",
            .levelsAchievementStreaks: "Rachas diarias: 100-300 XP",
            .levelsAchievementReviews: "Reseñas escritas: 50-1000 XP",
            .levelsAndMore: "Y muchos más...",
            .levelsBenefitsTitle: "Beneficios por nivel",
            .levelsBenefitsDesc: "A medida que subes de nivel, tus reseñas aparecerán primero en la lista destacada de cada campo, dándote mayor visibilidad ante otros usuarios.",
            .levelsTotal: "Total: %d XP",

            // Edit Profile
            .editProfileTitle: "Editar Perfil",
            .editProfileAddPhoto: "Añadir foto",
            .editProfileChangePhoto: "Cambiar foto",
            .editProfileDeletePhoto: "Eliminar foto",
            .editProfilePhotoSection: "Foto de Perfil",
            .editProfilePersonalInfo: "Información Personal",
            .editProfileNamePlaceholder: "Nombre",
            .editProfileSurnamePlaceholder: "Apellidos",
            .editProfileEmailSection: "Email",
            .editProfileEmailPlaceholder: "Email",
            .editProfileRequestEmailChange: "Solicitar cambio de email",
            .editProfileEmailChangeFooter: "El cambio de email requiere verificación mediante código enviado a tu nuevo correo. Esta funcionalidad estará disponible próximamente.",
            .editProfileEmailChangeWarning: "⚠️ El cambio de email con verificación estará disponible próximamente",
            .editProfilePasswordSection: "Seguridad",
            .editProfileChangePassword: "Cambiar contraseña",
            .editProfilePasswordFooter: "La contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula y un número.",
            .editProfileNewPassword: "Nueva contraseña",
            .editProfileConfirmPassword: "Confirmar contraseña",
            .editProfileSavingChanges: "Guardando cambios...",
            .editProfileSaveChanges: "Guardar cambios",
            .editProfileDeletePhotoConfirm: "Esta acción no se puede deshacer.",
            .editProfilePasswordStrength: "Fortaleza:",

            // Password Reset
            .passwordResetTitle: "Restablecer Contraseña",
            .passwordResetDesc: "Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.",
            .passwordResetEmailPlaceholder: "correo@ejemplo.com",
            .passwordResetButton: "Enviar enlace",
            .passwordResetSending: "Enviando...",
            .passwordResetSuccess: "Enlace enviado. Revisa tu correo electrónico.",
            .passwordResetBackToLogin: "Volver al inicio de sesión",
            .passwordResetResendIn: "Reenviar en %ds",
            .passwordResetInvalidEmail: "Introduce un correo electrónico válido.",
            .passwordResetError: "Error al enviar el correo: %@",
            .passwordResetErrorRateLimit: "Has enviado demasiadas solicitudes. Espera unos minutos e inténtalo de nuevo.",
            .passwordResetErrorNetwork: "Sin conexión a internet. Comprueba tu conexión e inténtalo de nuevo.",
            .passwordResetErrorGeneric: "No hemos podido enviar el correo en este momento. Inténtalo de nuevo más tarde.",
            .passwordResetNewTitle: "Nueva contraseña",
            .passwordResetNewDesc: "Introduce tu nueva contraseña.",
            .passwordResetNewButton: "Cambiar contraseña",
            .passwordResetNewSuccess: "Contraseña actualizada correctamente.",
            .passwordResetNewError: "Error al cambiar la contraseña: %@",
            .passwordResetNewMismatch: "Las contraseñas no coinciden.",
            .passwordResetNewErrorSamePassword: "La nueva contraseña debe ser diferente a la actual.",
            .passwordResetNewErrorShort: "La contraseña es demasiado corta (mínimo 6 caracteres).",
            .passwordResetNewErrorWeak: "La contraseña no es suficientemente segura. Usa letras, números y símbolos.",
            .passwordResetNewErrorExpired: "El enlace de recuperación ha caducado. Solicita un nuevo correo de restablecimiento.",
            .passwordResetNewErrorSession: "Tu sesión ha caducado. Solicita un nuevo correo de restablecimiento.",
            .passwordResetNewErrorNetwork: "Sin conexión a internet. Comprueba tu conexión e inténtalo de nuevo.",
            .passwordResetNewErrorGeneric: "No hemos podido actualizar la contraseña. Inténtalo de nuevo más tarde.",

            // Navigation Tabs
            .tabHome: "Inicio",
            .tabMap: "Mapa",
            .tabNearby: "Cercanos",
            .tabProfile: "Usuario",

            // Navigation Alerts
            .navRouteInProgress: "Ruta en curso",
            .navContinueRoute: "Continuar ruta",
            .navStopAndExit: "Detener y Salir",
            .navCancelMessage: "¿Deseas cancelar la navegación actual? El mapa volverá a su estado inicial.",
            .navVerification: "Verificación",
            .navVerificationSuccess: "¡Correo verificado! Ya puedes iniciar sesión.",
            .navVerificationError: "El enlace de verificación ha expirado o ya fue usado.",
            .navAccept: "Aceptar",

            // Campo Sections
            .campoPhotos: "Fotos",
            .campoPhotoBy: "Por %@",
            .campoDetails: "Detalles del campo",
            .campoLocation: "Ubicación",
            .campoHowToGet: "Cómo llegar",
            .campoContribute: "Contribuir información",
            .campoUnknownUser: "Usuario desconocido",

            // Review Actions
            .reviewEditAction: "Editar",
            .reviewDeleteAction: "Eliminar",
            .reviewWriteNew: "Escribir una reseña",
            .reviewsAndRatings: "Valoraciones y reseñas",
            .reviewLoadError: "Error al cargar",
            .reviewAddPhotosCount: "Añadir fotos (%d/%d)",

            // Preferences
            .preferencesTitle: "Preferencias",

            // Review Stats
            .reviewRating: "valoración",
            .reviewRatings: "valoraciones",
            .reviewNoRatingsYet: "Sin valoraciones todavía",
            .reviewEditMine: "Editar mi reseña",
            .reviewSingle: "reseña",
            .reviewPlural: "reseñas",
            .reviewNoReviewsYet: "Sin reseñas todavía",
            .reviewBeFirst: "Sé el primero en dejar tu opinión",
            .reviewEdited: "Editada",
            .reviewEditedAt: "Editada · %@",
            .reviewOf: "de",
            .reviewLoginToOpine: "Inicia sesión para opinar",
            .reviewShareExperience: "Comparte tu experiencia con la comunidad",
            .reviewVisitFirst: "Visita el campo primero",
            .reviewOnlyVisited: "Solo puedes reseñar campos que hayas visitado",
            .reviewAlreadyLeft: "Ya dejaste tu opinión",
            .reviewOnlyOne: "Solo puedes dejar una reseña por campo",
            .reviewRetry: "Reintentar",
            .reviewCompleted: "¡Completado!",

            // Daily Reward Extra
            .dailyRewardClaimedToday: "Recompensa reclamada hoy",
            .dailyRewardTestNotif: "Probar notificación en 20s",

            // Preferences Extra
            .preferencesDistance: "Distancia predeterminada para búsqueda de campos cercanos:",
            .preferencesDistanceKm: "%d km",

            // Profile Stats
            .profileStats: "Tus Estadísticas",
            .profileVisitHistory: "Últimas Visitas",
            .profileNoVisitsYet: "Aún no has visitado ningún campo",

            // Provinces
            .provinceACoruna: "A Coruña",
            .provinceOurense: "Ourense",
            .provinceLugo: "Lugo",
            .provincePontevedra: "Pontevedra",

            // Test Notifications
            .testNotificationTitle: "Test notificación",
            .testNotificationBody: "Debería aparecer en %d segundos",

            // Configuration Errors
            .errorSupabaseCredentials: "❌ Credenciales de Supabase inválidas. Ver EnvironmentConfig.swift",
            .errorSupabaseInvalidURL: "❌ URL de Supabase inválida: %@",

            // Authentication Errors
            .errorUserNotAuthenticated: "Usuario no autenticado",
            .errorCouldNotAuthenticate: "No se pudo autenticar el usuario",

            // Review Sort Types
            .reviewSortRecent: "Más recientes",
            .reviewSortOldest: "Más antiguas",
            .reviewSortHighest: "Mejor valoradas",
            .reviewSortLowest: "Peor valoradas",

            // Review Manager Errors
            .errorLoadingReviews: "Error al cargar reseñas: %@",
            .errorCouldNotUpdateReview: "No se pudo actualizar la reseña",
            .errorUpdatingReview: "Error al actualizar reseña: %@",
            .errorDeletingReview: "Error al eliminar reseña: %@",

            // Profile Errors
            .errorMultiplePreferences: "Error: Múltiples registros de preferencias encontrados.",
            .errorLogout: "Error al cerrar sesión: %@",

            // Success Messages
            .successPreferencesSaved: "✅ Preferencias guardadas con éxito",

            // UI Elements
            .reviewAnonymousName: "Anónimo",
            .reviewShowLess: "Menos",
            .reviewShowMore: "Más",
            .preferencesButtonSaving: "Guardando...",
            .preferencesButtonSave: "Guardar Preferencias",
            .reviewRatingLabel: "Valoración",

            // Connection Status
            .connectionTypeCellular: "Datos móviles",
            .connectionTypeUnknown: "Desconocido",
            .connectionOffline: "Sin conexión a internet",

            // Settings
            .settingsTitle: "Ajustes",
            .settingsGeneral: "General",
            .settingsAccount: "Cuenta",
            .settingsTheme: "Tema de la aplicación",
            .settingsThemeLight: "Claro",
            .settingsThemeDark: "Oscuro",
            .settingsThemeSystem: "Sistema",

            // Detail Views
            .reviewDetailTitle: "Reseña",
            .logrosDetailTitle: "Logro",
            .logrosDetailCompleted: "Completado",
            .logrosDetailProgress: "Progreso",
            .reviewDeleteConfirmTitle: "Eliminar reseña",
            .reviewDeleteConfirmMessage: "¿Estás seguro de que quieres eliminar tu reseña? Esta acción no se puede deshacer.",

            // Legal / Info section
            .settingsInfo: "Información",
            .settingsTerms: "Términos y Condiciones",
            .settingsContact: "Contacto",
            .settingsSuggest: "Sugerir un campo",

            // Términos y Condiciones
            .termsTitle: "Términos y Condiciones",
            .termsLastUpdated: "Última actualización: febrero de 2025",
            .termsSection1Title: "1. Objeto del servicio",
            .termsSection1Body: "Campos de Galicia es una aplicación móvil que permite a los usuarios descubrir, visitar y valorar campos de fútbol de Galicia (España). La app es de carácter recreativo y social, sin ánimo de lucro directo para el usuario.\n\nEl uso de la aplicación implica la aceptación plena de estos Términos. Si no estás de acuerdo, debes dejar de usar la app.",
            .termsSection2Title: "2. Registro y cuenta de usuario",
            .termsSection2Body: "Para acceder a las funcionalidades completas es necesario crear una cuenta con correo electrónico y contraseña. El usuario es responsable de mantener la confidencialidad de sus credenciales. Está prohibido crear cuentas con datos falsos o suplantar la identidad de terceros.",
            .termsSection3Title: "3. Protección de datos y privacidad (RGPD)",
            .termsSection3Body: "De conformidad con el Reglamento (UE) 2016/679 (RGPD) y la Ley Orgánica 3/2018 (LOPDGDD):\n\n• Responsable del tratamiento: Campos de Galicia (contacto: info@camposdegalicia.es)\n• Datos recogidos: correo electrónico, nombre, foto de perfil (opcional), historial de visitas y ubicación aproximada para validar visitas.\n• Finalidad: gestión de la cuenta, funcionamiento de la app y mejora del servicio.\n• Base legal: ejecución del contrato (art. 6.1.b RGPD) y consentimiento del usuario.\n• Tus derechos: acceso, rectificación, supresión, portabilidad y oposición. Ejecítalos escribiendo a info@camposdegalicia.es.\n• No cedemos datos a terceros salvo obligación legal.\n• Datos de ubicación: solo se usan para validar la proximidad a un campo y no se almacenan de forma continua.",
            .termsSection4Title: "4. Contenido generado por el usuario",
            .termsSection4Body: "Las reseñas, fotos y sugerencias enviadas son responsabilidad del usuario. Queda prohibido publicar contenido ofensivo, difamatorio, ilegal o que vulnere derechos de terceros. Nos reservamos el derecho a eliminar contenido que incumpla estas normas.",
            .termsSection5Title: "5. Propiedad intelectual",
            .termsSection5Body: "El diseño, código fuente, logotipos y contenidos originales de Campos de Galicia son propiedad de sus creadores y están protegidos por la legislación de propiedad intelectual. Los datos de campos proceden de fuentes públicas. Queda prohibida su reproducción sin autorización.",
            .termsSection6Title: "6. Legislación aplicable",
            .termsSection6Body: "Estos Términos se rigen por la legislación española. Para cualquier controversia, las partes se someten a los juzgados y tribunales del domicilio del usuario, salvo que la ley establezca otro fuero imperativo.\n\nContacto: info@camposdegalicia.es",

            // Contacto
            .contactTitle: "Contacto",
            .contactSubtitle: "¿Tienes alguna duda, sugerencia o has encontrado un error? Estamos para ayudarte.",
            .contactEmailLabel: "Correo de contacto",
            .contactEmailAction: "Enviar correo",
            .contactSuggestHint: "También puedes sugerir campos que no estén en la app usando el formulario de sugerencias.",

            // Sugerir Campo
            .suggestTitle: "Sugerir un Campo",
            .suggestSubtitle: "¿Conoces un campo que no está en la app? Cuéntanos y lo añadiremos.",
            .suggestFieldName: "Nombre del campo",
            .suggestFieldNamePlaceholder: "Ej. Campo Municipal de O Porriño",
            .suggestMunicipality: "Municipio",
            .suggestMunicipalityPlaceholder: "Ej. O Porriño",
            .suggestProvince: "Provincia",
            .suggestNotes: "Notas adicionales",
            .suggestNotesPlaceholder: "Dirección, referencias o cualquier detalle que nos ayude a localizarlo...",
            .suggestSend: "Enviar sugerencia",
            .suggestSending: "Enviando...",
            .suggestSuccessTitle: "¡Gracias!",
            .suggestSuccessMessage: "Tu sugerencia ha sido enviada. La revisaremos y añadiremos el campo si cumple los requisitos.",
            .suggestErrorEmpty: "El nombre del campo es obligatorio.",
            .suggestErrorGeneral: "No se pudo enviar la sugerencia. Inténtalo de nuevo.",
            .suggestLoginRequired: "Inicia sesión",
            .suggestLoginRequiredMessage: "Necesitas una cuenta para enviar sugerencias.",
            .suggestAnotherOne: "Sugerir otro campo",
        ],

        // MARK: - Galego
        .galician: [
            // General
            .appName: "Campos de Galicia",
            .cancel: "Cancelar",
            .save: "Gardar",
            .ok: "OK",
            .send: "Enviar",
            .next: "Seguinte",
            .skip: "Saltar",
            .start: "Comezar",
            .loading: "Cargando...",
            .error: "Erro",
            .success: "Éxito",

            // Onboarding
            .onboardingWelcomeTitle: "Benvido a Campos de Galicia!",
            .onboardingWelcomeMessage: "Descobre os campos de fútbol de toda Galicia. Visita, explora e colecciona ubicacións reais mentres gañas XP.",
            .onboardingMissionsTitle: "Misións e XP",
            .onboardingMissionsBullet1: "Marca campos como visitados cando esteas preto do campo (200m).",
            .onboardingMissionsBullet2: "Completa misións visitando campos e mantendo rachas diarias.",
            .onboardingMissionsBullet3: "Gaña XP e sube de nivel. Explora Galicia e progresa!",
            .onboardingAutoCheckinTitle: "Auto Check-in",
            .onboardingAutoCheckinMessage: "O auto check-in rexistra a túa visita automaticamente cando esteas preto dun campo (200m) e permanezcas alí 2 minutos.",
            .onboardingAutoCheckinBullet1: "Funciona en segundo plano con moi baixo consumo de batería.",
            .onboardingAutoCheckinBullet2: "Non rastrexa a túa ubicación constantemente.",
            .onboardingAutoCheckinBullet3: "Require permanencia de 2 minutos na área.",
            .onboardingAutoCheckinBullet4: "Só se rexistra unha vez por campo.",
            .onboardingNotificationsTitle: "Notificacións",
            .onboardingNotificationsMessage: "Avisarémosche cando a túa recompensa diaria estea lista e cando visites un campo automaticamente.",
            .onboardingNotificationsButton: "Permitir Notificacións",
            .onboardingLocationTitle: "Permitir ubicación",
            .onboardingLocationMessage: "Necesitamos a túa ubicación só para verificar que visitas os campos de verdade e rexistrar os teus logros.",
            .onboardingLocationButton: "Permitir Ubicación",
            .onboardingPermissionsGranted: "Permisos outorgados",
            .onboardingPermissionsDenied: "Permisos denegados",
            .onboardingPermissionsNotDetermined: "Permiso non determinado",
            .onboardingPermissionsUnknown: "Estado descoñecido",
            .onboardingLocationServicesDisabled: "Servizos de localización desactivados",
            .onboardingOpenSettings: "Abrir Axustes",
            .onboardingSettingsTitle: "Personaliza a túa experiencia",
            .onboardingSettingsLanguage: "Idioma",
            .onboardingSettingsTheme: "Aparencia",
            .onboardingFeaturesTitle: "Como funciona",
            .onboardingFeaturesBullet1: "Visita campos reais e rexístraos automaticamente ao estar preto.",
            .onboardingFeaturesBullet2: "Completa logros, mantén rachas e sube de nivel.",
            .onboardingFeaturesBullet3: "Escribe recensións e comparte a túa experiencia.",
            .onboardingFeaturesBullet4: "Explora o mapa e descobre campos preto de ti.",
            .onboardingPermissionsTitle: "Permisos necesarios",
            .onboardingPermissionsMessage: "Para rexistrar as túas visitas automaticamente necesitamos acceso á túa ubicación e notificacións.",
            .onboardingAccountTitle: "Crea a túa conta",
            .onboardingAccountMessage: "Cunha conta poderás acceder a todas as funcionalidades:",
            .onboardingAccountBullet1: "Gardar as túas visitas e progreso.",
            .onboardingAccountBullet2: "Desbloquear logros e gañar XP.",
            .onboardingAccountBullet3: "Escribir recensións e participar na comunidade.",
            .onboardingAccountCreateButton: "Crear conta",
            .onboardingAccountSkip: "Continuar sen conta",
            .onboardingAccountCreating: "Creando conta...",
            .onboardingAccountSuccess: "¡Conta creada!",
            .onboardingAccountSuccessMessage: "Xa podes gozar de todas as funcionalidades.",

            // Auth
            .loginTitle: "Campos de Galicia",
            .loginSubtitle: "Descobre os campos de fútbol de Galicia",
            .loginEmail: "Correo Electrónico",
            .loginEmailPlaceholder: "teu@email.com",
            .loginPassword: "Contrasinal",
            .loginButton: "Iniciar Sesión",
            .loginLoading: "Iniciando sesión...",
            .loginForgotPassword: "Esqueciches o contrasinal?",
            .loginNoAccount: "Non tes conta?",
            .loginCreateAccount: "Crear conta",
            .loginError: "Erro ao iniciar sesión: %@",
            .loginErrorInvalidCredentials: "Email ou contrasinal incorrectos.",
            .loginErrorEmailNotConfirmed: "Debes verificar o teu correo electrónico antes de iniciar sesión.",
            .loginErrorRateLimit: "Demasiados intentos. Agarda uns minutos e téntao de novo.",
            .loginErrorNetwork: "Non hai conexión a internet. Comproba a túa conexión e téntao de novo.",
            .loginErrorGeneric: "Non puidemos iniciar sesión. Téntao de novo máis tarde.",

            .registerTitle: "Crear Conta",
            .registerSubtitle: "Únete á comunidade de Campos de Galicia",
            .registerName: "Nome",
            .registerNamePlaceholder: "O teu nome",
            .registerSurname: "Apelidos",
            .registerSurnamePlaceholder: "Os teus apelidos",
            .registerProfilePhoto: "Foto de perfil (opcional)",
            .registerSelectPhoto: "Seleccionar foto",
            .registerChangePhoto: "Cambiar foto",
            .registerDeletePhoto: "Eliminar",
            .registerButton: "Crear conta",
            .registerLoading: "Creando conta...",
            .registerPasswordHint: "Mínimo 8 caracteres, con maiúscula, minúscula e número",
            .registerNavTitle: "Rexistro",
            .registerSuccessTitle: "Rexistro Exitoso!",
            .registerSuccessMessage: "A túa conta foi creada. Por favor revisa o teu correo para verificar a túa conta.",
            .registerErrorAllFields: "Todos os campos son obrigatorios.",
            .registerErrorInvalidEmail: "Introduce un correo electrónico válido.",
            .registerErrorPasswordShort: "O contrasinal debe ter polo menos 8 caracteres.",
            .registerErrorPasswordUppercase: "O contrasinal debe conter polo menos unha letra maiúscula.",
            .registerErrorPasswordLowercase: "O contrasinal debe conter polo menos unha letra minúscula.",
            .registerErrorPasswordNumber: "O contrasinal debe conter polo menos un número.",
            .registerErrorAlreadyExists: "Ese correo xa está rexistrado. Inicia sesión ou usa 'Esqueciches o contrasinal?'.",
            .registerErrorInvalidEmailFormat: "O correo non é válido. Revisa o formato (ex. usuario@dominio.com).",
            .registerErrorRateLimit: "Fixeches demasiadas solicitudes. Inténtao de novo nuns minutos.",
            .registerErrorProfile: "Produciuse un problema ao crear o teu perfil. Volve tentalo nuns segundos.",
            .registerErrorDuplicate: "Xa existía un perfil asociado a este usuario. Inicia sesión co teu correo.",
            .registerErrorGeneral: "Non puidemos crear a túa conta agora mesmo. Inténtao de novo nuns minutos.",

            // Campo Detail
            .campoLoading: "Cargando información do campo...",
            .campoNoCoordinates: "Este campo aínda non ten coordenadas. Axúdanos a engadilas",
            .campoLocationDenied: "Activa a ubicación en: Axustes → Privacidade e Seguridade → Ubicación → Campos de Galicia",
            .campoLocationNeeded: "Necesitamos permiso para acceder á túa ubicación",
            .campoLocationError: "Non puidemos obter a túa ubicación. Asegúrate de estar nun lugar con boa señal GPS",
            .campoGPSWeak: "A señal GPS é débil (%dm de precisión). Sae ao exterior para mellor precisión",
            .campoTooFar: "Estás a ~%@ do campo. Achégate máis (necesitas estar a %@ ou menos)",
            .campoVisitSuccess: "Visitaches %@",
            .campoVisitSuccessTitle: "✅ Éxito!",
            .campoVisitError: "Erro ao rexistrar visita",
            .campoVisitErrorTitle: "Non se puido marcar a visita",
            .campoUnvisitSuccess: "Visita desmarcada",
            .campoUnvisitError: "Erro ao desmarcar visita",
            .campoDefaultName: "Campo",

            // Logros
            .logrosTitle: "Logros e Recompensas",
            .logrosPending: "Pendentes",
            .logrosCompleted: "Completados",
            .logrosLoading: "Cargando logros...",
            .logrosAllCompleted: "Parabéns! Completaches todos os logros.",
            .logrosAllCompletedMessage: "Es un auténtico explorador de Galicia!",
            .logrosNone: "Aínda non tes logros",
            .logrosNoneMessage: "Visita campos, escribe recensións e mantén rachas para desbloquear logros",
            .logrosProgressTitle: "O teu Progreso",
            .logrosProgressCampos: "Campos",
            .logrosProgressProvincias: "Provincias",
            .logrosProgressRacha: "Racha",
            .logrosProgressReviews: "Recensións",
            .logrosCamposVisitados: "Campos visitados",
            .logrosRachasDiarias: "Rachas diarias",
            .logrosReseñas: "Recensións",
            .logrosOtros: "Outros",

            // Daily Reward
            .dailyRewardTitle: "Recompensa Diaria",
            .dailyRewardClaimed: "Xa reclamaches hoxe!",
            .dailyRewardClaim: "Reclamar +%d XP",
            .dailyRewardDay: "Día %d",
            .dailyRewardStreak: "racha",
            .dailyRewardProcessing: "Procesando...",
            .dailyRewardNotificationTitle: "Campos de Galicia",
            .dailyRewardNotificationBody: "A túa recompensa diaria espérate! Recláma agora na sección de Logros 🎁",
            .dailyStreakWarningBody: "A túa racha de %d días está en perigo! Entra e reclama a túa recompensa para non perdela 🔥",
            .logrosStreakCurrent: "racha actual",
            .logrosStreakWeeklyCycle: "ciclo semanal",
            .logrosStreakDaysSingular: "día",
            .logrosStreakDaysPlural: "días",
            .logrosMasterName: "Mestre de Campos",
            .logrosMasterDesc: "Completaches todos os logros. Es unha lenda!",
            .logrosMasterToast: "🏅 Mestre de Campos! +%d XP",

            // Notifications
            .notifDisabledTitle: "Notificacións desactivadas",
            .notifDisabledMessage: "Activa as notificacións para recibir avisos cando a túa recompensa diaria estea lista e non perderes ningún día.",
            .notifGoToSettings: "Ir a Axustes",
            .notifAutoCheckinTitle: "Campo visitado!",
            .notifAutoCheckinBody: "Visitaches %@. Un campo máis para a túa colección! ⚽",
            .notifAutoCheckinErrorTitle: "Non se puido rexistrar a visita",
            .notifAutoCheckinErrorBody: "Non puidemos rexistrar a túa visita a %@. Revisa a túa conexión e inténtao de novo.",

            // Reviews
            .reviewAdd: "Nova Recensión",
            .reviewEdit: "Editar Recensión",
            .reviewYourRating: "A túa valoración",
            .reviewYourOpinion: "A túa opinión",
            .reviewPlaceholder: "Cóntanos a túa experiencia neste campo...",
            .reviewGuidelines: "Sé respectuoso e describe a túa experiencia de forma honesta.",
            .reviewPhotosOptional: "Fotos (opcional)",
            .reviewPhotosHelp: "Sube fotos do campo para axudar a outros visitantes (máximo %d).",
            .reviewAnonymous: "Recensión anónima",
            .reviewAnonymousHelp: "Se activas esta opción, o teu nome non será visible na recensión.",
            .reviewPublish: "Publicar",
            .reviewPublishing: "Publicando recensión...",
            .reviewUpdating: "Actualizando recensión...",
            .reviewPublished: "Recensión publicada!",
            .reviewUpdated: "Recensión actualizada!",
            .reviewRatingVeryBad: "😞 Moi malo",
            .reviewRatingBad: "😕 Malo",
            .reviewRatingRegular: "😐 Regular",
            .reviewRatingGood: "😊 Bo",
            .reviewRatingExcellent: "🤩 Excelente",

            // Contribuciones
            .contribucionTitle: "Achegar información",
            .contribucionHelp: "Axuda a completar os datos de %@",
            .contribucionAddPhotos: "Engadir fotos",
            .contribucionCantina: "Ten cantina?",
            .contribucionAforo: "Aforo da bancada (número)",
            .contribucionMedidas: "Medidas do campo (ex. 105x68 metros)",
            .contribucionIluminacion: "Tipo de iluminación",
            .contribucionIluminacionNatural: "Natural",
            .contribucionIluminacionArtificial: "Artificial",
            .contribucionCesped: "Estado do céspede",
            .contribucionCespedBueno: "Bo",
            .contribucionCespedRegular: "Regular",
            .contribucionCespedMalo: "Malo",
            .contribucionAccesibilidad: "Accesibilidade",
            .contribucionAccesibilidadSi: "Si, ten acceso para persoas con discapacidade",
            .contribucionAccesibilidadNo: "Non, non ten acceso",
            .contribucionParking: "Ten aparcadoiro?",
            .contribucionSuccess: "✅ Contribución enviada. Grazas!",
            .contribucionError: "Erro ao enviar a contribución",
            .contribucionSelect: "Seleccionar",

            // Toast
            .toastVisited: "✅ Visitado! %@",
            .toastUnvisited: "Visita desmarcada",
            .toastXPGained: "+%d XP - %@",
            .toastLevelUp: "⬆️ Nivel %d acadado!",
            .toastAchievement: "🏆 Novo logro! %@",

            // Profile
            .profileLanguage: "Idioma",
            .profileLanguageTitle: "Seleccionar idioma",
            .profileLanguageMessage: "Escolle o idioma da aplicación",

            // Empty States
            .emptyNoData: "Non hai datos dispoñibles",

            // Loading
            .loadingCampos: "Cargando campos de Galicia...",
            .loadingCampoInfo: "Cargando información do campo...",
            .loadingLogros: "Cargando logros...",
            .loadingLocation: "Obtendo a túa ubicación...",

            // ContentView
            .contentHome: "Inicio",
            .contentShownFields: "Mostrados %d campos",
            .contentAllProvinces: "Todas",
            .contentFilterLabel: "Filtrar:",
            .contentSearchByName: "Buscar campo ou localidade...",
            .contentSearchByLocation: "Buscar por localidade",
            .contentProvince: "Provincia:",
            .contentApply: "Aplicar",
            .contentReset: "Resetear",

            // Map View
            .mapSearchPlaceholder: "Buscar campo...",
            .mapContinueStraight: "Continúa recto",
            .mapDestination: "Destino",
            .mapKilometers: "kilómetros",
            .mapMinutesApprox: "minutos aprox.",
            .mapStartNavigation: "Iniciar navegación",
            .mapFootballField: "Campo de fútbol",
            .mapOf: "de",

            // Nearby Campos
            .nearbyCamposTitle: "Campos cercanos",
            .nearbyMaxDistance: "Distancia máxima",
            .nearbyNoFieldsFound: "Non se atoparon campos cercanos dentro de %d km.",
            .nearbyLocationError: "Non se puido obter a ubicación. Habilita os servizos de localización.",
            .nearbyDistance: "Distancia: %.1f km",

            // Profile
            .profileTitle: "Perfil",
            .profileHello: "Ola, %@!",
            .profileLevel: "Nivel %d",
            .profileAutoCheckin: "Auto Check-in",
            .profileAutoCheckinDesc: "Rexistrar visitas automaticamente ao estar 2 minutos preto dun campo",
            .profileAutoCheckinWarning: "⚠️ Necesítanse permisos de ubicación 'Sempre' para o auto check-in",
            .profilePersonalInfo: "Información Persoal",
            .profileEdit: "Editar",
            .profileName: "Nome",
            .profileSurname: "Apelidos",
            .profileEmail: "Email",
            .profileNotAvailable: "Non dispoñible",
            .profileLogout: "Pechar Sesión",
            .profileAutoCheckinInfoTitle: "Auto Check-in",
            .profileAutoCheckinInfoDesc: "O auto check-in rexistra automaticamente a túa visita cando estás dentro de 200m dun campo e permaneces alí durante 2 minutos.",
            .profileAutoCheckinInfoHow: "Como funciona:",
            .profileAutoCheckinInfoDetect: "Detecta cando entras en 200m dun campo",
            .profileAutoCheckinInfoWait: "Espera 2 minutos de permanencia na área",
            .profileAutoCheckinInfoRegister: "Rexistra a visita automaticamente",
            .profileAutoCheckinInfoNoRepeat: "Non se repite se xa visitaches o campo",
            .profileAutoCheckinInfoReqs: "Requisitos:",
            .profileAutoCheckinInfoReqAlways: "Permisos de ubicación 'Sempre'",
            .profileAutoCheckinInfoReqBackground: "Manter a app en segundo plano",
            .profileAutoCheckinInfoReqInternet: "Conexión a internet para gardar",
            .profileClose: "Pechar",

            // Levels Info
            .levelsTitle: "Niveis",
            .levelsInfoTitle: "Información sobre Niveis",
            .levelsWhatFor: "Para que serven os niveis?",
            .levelsBenefitVisibility: "Maior visibilidade das túas recensións",
            .levelsBenefitRecognition: "Recoñecemento dentro da comunidade",
            .levelsBenefitProgress: "Seguimento do teu progreso e dedicación",
            .levelsBenefitUnlock: "Desbloqueo de logros e recompensas",
            .levelsHowToGetXP: "Como conseguir XP?",
            .levelsVisitFields: "Visitar campos",
            .levelsVisitFieldsDesc: "Marca campos como visitados para gañar XP",
            .levelsVariable: "Variable",
            .levelsWriteReviews: "Escribir recensións",
            .levelsWriteReviewsDesc: "Deixa recensións en campos visitados",
            .levelsReviewBase: "Base: 25 XP",
            .levelsReviewDetailed: "Recensión detallada (+100 caracteres): +10 XP",
            .levelsReviewPhotos: "Con fotos: +15 XP",
            .levelsReviewEdited: "Editada/mellorada: +5 XP",
            .levelsDailyReward: "Recompensa diaria",
            .levelsDailyRewardDesc: "Reclama a túa recompensa cada día na sección de Logros",
            .levelsDailyDay: "Día %d: %d XP",
            .levelsUnlockAchievements: "Desbloquear logros",
            .levelsUnlockAchievementsDesc: "Completa obxectivos para gañar XP extra",
            .levelsAchievementFields: "Campos visitados: 50-500 XP",
            .levelsAchievementStreaks: "Rachas diarias: 100-300 XP",
            .levelsAchievementReviews: "Recensións escritas: 50-1000 XP",
            .levelsAndMore: "E moitos máis...",
            .levelsBenefitsTitle: "Beneficios por nivel",
            .levelsBenefitsDesc: "A medida que sobes de nivel, as túas recensións aparecerán primeiro na lista destacada de cada campo, dándoche maior visibilidade ante outros usuarios.",
            .levelsTotal: "Total: %d XP",

            // Edit Profile
            .editProfileTitle: "Editar Perfil",
            .editProfileAddPhoto: "Engadir foto",
            .editProfileChangePhoto: "Cambiar foto",
            .editProfileDeletePhoto: "Eliminar foto",
            .editProfilePhotoSection: "Foto de Perfil",
            .editProfilePersonalInfo: "Información Persoal",
            .editProfileNamePlaceholder: "Nome",
            .editProfileSurnamePlaceholder: "Apelidos",
            .editProfileEmailSection: "Email",
            .editProfileEmailPlaceholder: "Email",
            .editProfileRequestEmailChange: "Solicitar cambio de email",
            .editProfileEmailChangeFooter: "O cambio de email require verificación mediante código enviado ao teu novo correo. Esta funcionalidade estará dispoñible proximamente.",
            .editProfileEmailChangeWarning: "⚠️ O cambio de email con verificación estará dispoñible proximamente",
            .editProfilePasswordSection: "Seguridade",
            .editProfileChangePassword: "Cambiar contrasinal",
            .editProfilePasswordFooter: "O contrasinal debe ter polo menos 8 caracteres, unha maiúscula, unha minúscula e un número.",
            .editProfileNewPassword: "Novo contrasinal",
            .editProfileConfirmPassword: "Confirmar contrasinal",
            .editProfileSavingChanges: "Gardando cambios...",
            .editProfileSaveChanges: "Gardar cambios",
            .editProfileDeletePhotoConfirm: "Esta acción non se pode desfacer.",
            .editProfilePasswordStrength: "Fortaleza:",

            // Password Reset
            .passwordResetTitle: "Restablecer Contrasinal",
            .passwordResetDesc: "Ingresa o teu correo electrónico e enviarémosche un enlace para restablecer o teu contrasinal.",
            .passwordResetEmailPlaceholder: "correo@exemplo.com",
            .passwordResetButton: "Enviar enlace",
            .passwordResetSending: "Enviando...",
            .passwordResetSuccess: "Enlace enviado. Revisa o teu correo electrónico.",
            .passwordResetBackToLogin: "Volver ao inicio de sesión",
            .passwordResetResendIn: "Reenviar en %ds",
            .passwordResetInvalidEmail: "Introduce un correo electrónico válido.",
            .passwordResetError: "Erro ao enviar o correo: %@",
            .passwordResetErrorRateLimit: "Enviaches demasiadas solicitudes. Agarda uns minutos e téntao de novo.",
            .passwordResetErrorNetwork: "Non hai conexión a internet. Comproba a túa conexión e téntao de novo.",
            .passwordResetErrorGeneric: "Non puidemos enviar o correo neste momento. Téntao de novo máis tarde.",
            .passwordResetNewTitle: "Novo contrasinal",
            .passwordResetNewDesc: "Introduce o teu novo contrasinal.",
            .passwordResetNewButton: "Cambiar contrasinal",
            .passwordResetNewSuccess: "Contrasinal actualizado correctamente.",
            .passwordResetNewError: "Erro ao cambiar o contrasinal: %@",
            .passwordResetNewMismatch: "Os contrasinais non coinciden.",
            .passwordResetNewErrorSamePassword: "O novo contrasinal debe ser diferente do actual.",
            .passwordResetNewErrorShort: "O contrasinal é demasiado curto (mínimo 6 caracteres).",
            .passwordResetNewErrorWeak: "O contrasinal non é suficientemente seguro. Usa letras, números e símbolos.",
            .passwordResetNewErrorExpired: "A ligazón de recuperación caducou. Solicita un novo correo de restablecemento.",
            .passwordResetNewErrorSession: "A túa sesión caducou. Solicita un novo correo de restablecemento.",
            .passwordResetNewErrorNetwork: "Non hai conexión a internet. Comproba a túa conexión e téntao de novo.",
            .passwordResetNewErrorGeneric: "Non puidemos actualizar o contrasinal. Téntao de novo máis tarde.",

            // Navigation Tabs
            .tabHome: "Inicio",
            .tabMap: "Mapa",
            .tabNearby: "Cercanos",
            .tabProfile: "Usuario",

            // Navigation Alerts
            .navRouteInProgress: "Ruta en curso",
            .navContinueRoute: "Continuar ruta",
            .navStopAndExit: "Deter e Saír",
            .navCancelMessage: "Desexas cancelar a navegación actual? O mapa volverá ao seu estado inicial.",
            .navVerification: "Verificación",
            .navVerificationSuccess: "Correo verificado! Xa podes iniciar sesión.",
            .navVerificationError: "A ligazón de verificación expirou ou xa foi usada.",
            .navAccept: "Aceptar",

            // Campo Sections
            .campoPhotos: "Fotos",
            .campoPhotoBy: "Por %@",
            .campoDetails: "Detalles do campo",
            .campoLocation: "Ubicación",
            .campoHowToGet: "Como chegar",
            .campoContribute: "Contribuír información",
            .campoUnknownUser: "Usuario descoñecido",

            // Review Actions
            .reviewEditAction: "Editar",
            .reviewDeleteAction: "Eliminar",
            .reviewWriteNew: "Escribir unha recensión",
            .reviewsAndRatings: "Valoracións e recensións",
            .reviewLoadError: "Erro ao cargar",
            .reviewAddPhotosCount: "Engadir fotos (%d/%d)",

            // Preferences
            .preferencesTitle: "Preferencias",

            // Review Stats
            .reviewRating: "valoración",
            .reviewRatings: "valoracións",
            .reviewNoRatingsYet: "Sen valoracións todavía",
            .reviewEditMine: "Editar miña recensión",
            .reviewSingle: "recensión",
            .reviewPlural: "recensións",
            .reviewNoReviewsYet: "Sen recensións todavía",
            .reviewBeFirst: "Sé o primeiro en deixar a túa opinión",
            .reviewEdited: "Editada",
            .reviewEditedAt: "Editada · %@",
            .reviewOf: "de",
            .reviewLoginToOpine: "Inicia sesión para opinar",
            .reviewShareExperience: "Comparte a túa experiencia coa comunidade",
            .reviewVisitFirst: "Visita o campo primeiro",
            .reviewOnlyVisited: "Só podes reseñar campos que visitaches",
            .reviewAlreadyLeft: "Xa deixaches a túa opinión",
            .reviewOnlyOne: "Só podes deixar unha recensión por campo",
            .reviewRetry: "Reintentar",
            .reviewCompleted: "Completado!",

            // Daily Reward Extra
            .dailyRewardClaimedToday: "Recompensa reclamada hoxe",
            .dailyRewardTestNotif: "Probar notificación en 20s",

            // Preferences Extra
            .preferencesDistance: "Distancia predeterminada para procura de campos cercanos:",
            .preferencesDistanceKm: "%d km",

            // Profile Stats
            .profileStats: "As túas Estadísticas",
            .profileVisitHistory: "Últimas Visitas",
            .profileNoVisitsYet: "Aínda non visitaches ningún campo",

            // Provinces
            .provinceACoruna: "A Coruña",
            .provinceOurense: "Ourense",
            .provinceLugo: "Lugo",
            .provincePontevedra: "Pontevedra",

            // Test Notifications
            .testNotificationTitle: "Test notificación",
            .testNotificationBody: "Debería aparecer en %d segundos",

            // Configuration Errors
            .errorSupabaseCredentials: "❌ Credenciais de Supabase inválidas. Ver EnvironmentConfig.swift",
            .errorSupabaseInvalidURL: "❌ URL de Supabase inválida: %@",

            // Authentication Errors
            .errorUserNotAuthenticated: "Usuario non autenticado",
            .errorCouldNotAuthenticate: "Non se puido autenticar o usuario",

            // Review Sort Types
            .reviewSortRecent: "Máis recentes",
            .reviewSortOldest: "Máis antigas",
            .reviewSortHighest: "Mellor valoradas",
            .reviewSortLowest: "Peor valoradas",

            // Review Manager Errors
            .errorLoadingReviews: "Erro ao cargar recensións: %@",
            .errorCouldNotUpdateReview: "Non se puido actualizar a recensión",
            .errorUpdatingReview: "Erro ao actualizar recensión: %@",
            .errorDeletingReview: "Erro ao eliminar recensión: %@",

            // Profile Errors
            .errorMultiplePreferences: "Erro: Múltiples rexistros de preferencias atopados.",
            .errorLogout: "Erro ao pechar sesión: %@",

            // Success Messages
            .successPreferencesSaved: "✅ Preferencias gardadas con éxito",

            // UI Elements
            .reviewAnonymousName: "Anónimo",
            .reviewShowLess: "Menos",
            .reviewShowMore: "Máis",
            .preferencesButtonSaving: "Gardando...",
            .preferencesButtonSave: "Gardar Preferencias",
            .reviewRatingLabel: "Valoración",

            // Connection Status
            .connectionTypeCellular: "Datos móbiles",
            .connectionTypeUnknown: "Descoñecido",
            .connectionOffline: "Sen conexión a internet",

            // Settings
            .settingsTitle: "Axustes",
            .settingsGeneral: "Xeral",
            .settingsAccount: "Conta",
            .settingsTheme: "Tema da aplicación",
            .settingsThemeLight: "Claro",
            .settingsThemeDark: "Escuro",
            .settingsThemeSystem: "Sistema",

            // Detail Views
            .reviewDetailTitle: "Recensión",
            .logrosDetailTitle: "Logro",
            .logrosDetailCompleted: "Completado",
            .logrosDetailProgress: "Progreso",
            .reviewDeleteConfirmTitle: "Eliminar recensión",
            .reviewDeleteConfirmMessage: "Estás seguro de que queres eliminar a túa recensión? Esta acción non se pode desfacer.",

            // Legal / Info section
            .settingsInfo: "Información",
            .settingsTerms: "Termos e Condicións",
            .settingsContact: "Contacto",
            .settingsSuggest: "Suxerir un campo",

            // Termos e Condicións
            .termsTitle: "Termos e Condicións",
            .termsLastUpdated: "Última actualización: febreiro de 2025",
            .termsSection1Title: "1. Obxecto do servizo",
            .termsSection1Body: "Campos de Galicia é unha aplicación móbil que permite aos usuarios descubrir, visitar e valorar campos de fútbol de Galicia (España). A app é de carácter recreativo e social, sen ánimo de lucro directo para o usuario.\n\nO uso da aplicación implica a aceptación plena destes Termos. Se non estás de acordo, debes deixar de usar a app.",
            .termsSection2Title: "2. Rexistro e conta de usuario",
            .termsSection2Body: "Para acceder ás funcionalidades completas é necesario crear unha conta con correo electrónico e contrasinal. O usuario é responsable de manter a confidencialidade das súas credenciais. Está prohibido crear contas con datos falsos ou suplantar a identidade de terceiros.",
            .termsSection3Title: "3. Protección de datos e privacidade (RXPD)",
            .termsSection3Body: "De conformidade co Regulamento (UE) 2016/679 (RXPD) e a Lei Orgánica 3/2018 (LOPDGDD):\n\n• Responsable do tratamento: Campos de Galicia (contacto: info@camposdegalicia.es)\n• Datos recollidos: correo electrónico, nome, foto de perfil (opcional), historial de visitas e localización aproximada para validar visitas.\n• Finalidade: xestión da conta, funcionamento da app e mellora do servizo.\n• Base legal: execución do contrato (art. 6.1.b RXPD) e consentimento do usuario.\n• Os teus dereitos: acceso, rectificación, supresión, portabilidade e oposición. Exérceos escribindo a info@camposdegalicia.es.\n• Non cedemos datos a terceiros salvo obrigación legal.\n• Datos de localización: só se usan para validar a proximidade a un campo e non se almacenan de forma continua.",
            .termsSection4Title: "4. Contido xerado polo usuario",
            .termsSection4Body: "As recensións, fotos e suxestións enviadas son responsabilidade do usuario. Está prohibido publicar contido ofensivo, difamatorio, ilegal ou que vulnere dereitos de terceiros. Reservámonos o dereito a eliminar contido que incumpra estas normas.",
            .termsSection5Title: "5. Propiedade intelectual",
            .termsSection5Body: "O deseño, código fonte, logotipos e contidos orixinais de Campos de Galicia son propiedade dos seus creadores e están protexidos pola lexislación de propiedade intelectual. Os datos de campos proceden de fontes públicas. Está prohibida a súa reprodución sen autorización.",
            .termsSection6Title: "6. Lexislación aplicable",
            .termsSection6Body: "Estes Termos réxense pola lexislación española. Para calquera controversia, as partes sométense aos xulgados e tribunais do domicilio do usuario, salvo que a lei estableza outro foro imperativo.\n\nContacto: info@camposdegalicia.es",

            // Contacto
            .contactTitle: "Contacto",
            .contactSubtitle: "Tes algunha dúbida, suxestión ou atopaches un erro? Estamos para axudarche.",
            .contactEmailLabel: "Correo de contacto",
            .contactEmailAction: "Enviar correo",
            .contactSuggestHint: "Tamén podes suxerir campos que non estean na app usando o formulario de suxestións.",

            // Suxerir Campo
            .suggestTitle: "Suxerir un Campo",
            .suggestSubtitle: "Coñeces un campo que non está na app? Cóntanos e engadirémolo.",
            .suggestFieldName: "Nome do campo",
            .suggestFieldNamePlaceholder: "Ex. Campo Municipal de O Porriño",
            .suggestMunicipality: "Concello",
            .suggestMunicipalityPlaceholder: "Ex. O Porriño",
            .suggestProvince: "Provincia",
            .suggestNotes: "Notas adicionais",
            .suggestNotesPlaceholder: "Dirección, referencias ou calquera detalle que nos axude a localizalo...",
            .suggestSend: "Enviar suxestión",
            .suggestSending: "Enviando...",
            .suggestSuccessTitle: "Grazas!",
            .suggestSuccessMessage: "A túa suxestión foi enviada. Revisarémosvola e engadiremos o campo se cumpre os requisitos.",
            .suggestErrorEmpty: "O nome do campo é obrigatorio.",
            .suggestErrorGeneral: "Non se puido enviar a suxestión. Téntao de novo.",
            .suggestLoginRequired: "Inicia sesión",
            .suggestLoginRequiredMessage: "Necesitas unha conta para enviar suxestións.",
            .suggestAnotherOne: "Suxerir outro campo",
        ]
    ]
}

// MARK: - SwiftUI Extension

extension View {
    /// Aplica el idioma actual del LocalizationManager
    func withLocalization() -> some View {
        self.environmentObject(LocalizationManager.shared)
    }
}

/// Helper para acceder a traducciones fácilmente
func L(_ key: LocalizedKey, _ args: CVarArg...) -> String {
    // Leer idioma actual desde UserDefaults (thread-safe)
    let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? Language.spanish.rawValue
    let currentLang = Language(rawValue: savedLang) ?? .spanish

    let format = LocalizationManager.shared.translations[currentLang]?[key] ?? key.rawValue
    if args.isEmpty {
        return format
    }
    return String(format: format, arguments: args)
}
