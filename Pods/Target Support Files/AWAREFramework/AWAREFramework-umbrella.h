#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "BLEScanner.h"
#import "Bluetooth.h"
#import "EntityBluetooth+CoreDataProperties.h"
#import "EntityBluetooth.h"
#import "BLEHeartRate.h"
#import "EntityBLEHeartRate+CoreDataProperties.h"
#import "EntityBLEHeartRate.h"
#import "Calendar.h"
#import "CalEvent.h"
#import "EntityCalendar+CoreDataClass.h"
#import "EntityCalendar+CoreDataProperties.h"
#import "CalendarESMScheduler.h"
#import "Contacts.h"
#import "EntityContact+CoreDataClass.h"
#import "EntityContact+CoreDataProperties.h"
#import "AWARECore.h"
#import "AWAREMotionSensor.h"
#import "AWARESensor.h"
#import "AWARESensorManager.h"
#import "AWARESensors.h"
#import "AWAREStorage.h"
#import "CSVStorage.h"
#import "JSONStorage.h"
#import "AWAREBatchDataOM+CoreDataClass.h"
#import "AWAREBatchDataOM+CoreDataProperties.h"
#import "SQLiteSeparatedStorage.h"
#import "SQLiteStorage.h"
#import "AWAREFetchSizeAdjuster.h"
#import "BaseCoreDataHandler.h"
#import "CoreDataHandler.h"
#import "ExternalCoreDataHandler.h"
#import "DBTableCreator.h"
#import "QuickSyncExecutor.h"
#import "StreamLineReader.h"
#import "SyncExecutor.h"
#import "TCQMaker.h"
#import "AWAREStudy.h"
#import "AWAREEventLogger.h"
#import "AWAREKeys.h"
#import "AWAREStatusMonitor.h"
#import "AWAREUtils.h"
#import "EntityAWAREStatus+CoreDataClass.h"
#import "EntityAWAREStatus+CoreDataProperties.h"
#import "EntityEventLog+CoreDataClass.h"
#import "EntityEventLog+CoreDataProperties.h"
#import "Reachability.h"
#import "Accelerometer.h"
#import "AWAREAccelerometerOM+CoreDataClass.h"
#import "AWAREAccelerometerOM+CoreDataProperties.h"
#import "EntityAccelerometer+CoreDataProperties.h"
#import "EntityAccelerometer.h"
#import "Barometer.h"
#import "AWAREBarometerOM+CoreDataClass.h"
#import "AWAREBarometerOM+CoreDataProperties.h"
#import "EntityBarometer+CoreDataProperties.h"
#import "EntityBarometer.h"
#import "BasicSettings.h"
#import "Battery.h"
#import "BatteryCharge.h"
#import "BatteryDischarge.h"
#import "EntityBattery+CoreDataProperties.h"
#import "EntityBattery.h"
#import "EntityBatteryCharge+CoreDataProperties.h"
#import "EntityBatteryCharge.h"
#import "EntityBatteryDischarge+CoreDataProperties.h"
#import "EntityBatteryDischarge.h"
#import "Calls.h"
#import "EntityCall+CoreDataProperties.h"
#import "EntityCall.h"
#import "AWAREDevice.h"
#import "DeviceUsage.h"
#import "EntityDeviceUsage+CoreDataProperties.h"
#import "EntityDeviceUsage.h"
#import "Fitbit.h"
#import "FitbitData.h"
#import "FitbitDevice.h"
#import "EntityFitbitData+CoreDataClass.h"
#import "EntityFitbitData+CoreDataProperties.h"
#import "EntityFitbitDevice+CoreDataClass.h"
#import "EntityFitbitDevice+CoreDataProperties.h"
#import "FusedLocations.h"
#import "AWAREGoogleLoginViewController.h"
#import "GoogleLogin.h"
#import "Gravity.h"
#import "AWAREGravityOM+CoreDataClass.h"
#import "AWAREGravityOM+CoreDataProperties.h"
#import "EntityGravity+CoreDataProperties.h"
#import "EntityGravity.h"
#import "Gyroscope.h"
#import "AWAREGyroscopeOM+CoreDataClass.h"
#import "AWAREGyroscopeOM+CoreDataProperties.h"
#import "EntityGyroscope+CoreDataProperties.h"
#import "EntityGyroscope.h"
#import "IOSESM.h"
#import "LinearAccelerometer.h"
#import "AWARELinearAccelerometerOM+CoreDataClass.h"
#import "AWARELinearAccelerometerOM+CoreDataProperties.h"
#import "EntityLinearAccelerometer+CoreDataProperties.h"
#import "EntityLinearAccelerometer.h"
#import "Locations.h"
#import "EntityLocation+CoreDataProperties.h"
#import "EntityLocation.h"
#import "Magnetometer.h"
#import "AWAREMagnetometerOM+CoreDataClass.h"
#import "AWAREMagnetometerOM+CoreDataProperties.h"
#import "EntityMagnetometer+CoreDataProperties.h"
#import "EntityMagnetometer.h"
#import "Memory.h"
#import "EntityMemory+CoreDataProperties.h"
#import "EntityMemory.h"
#import "Network.h"
#import "EntityNetwork+CoreDataProperties.h"
#import "EntityNetwork.h"
#import "NTPTime.h"
#import "EntityNTPTime+CoreDataProperties.h"
#import "EntityNTPTime.h"
#import "EntityOpenWeather+CoreDataProperties.h"
#import "EntityOpenWeather.h"
#import "OpenWeather.h"
#import "Orientation.h"
#import "EntityProcessor+CoreDataProperties.h"
#import "EntityProcessor.h"
#import "Processor.h"
#import "EntityProximity+CoreDataProperties.h"
#import "EntityProximity.h"
#import "Proximity.h"
#import "EntityPushNotification+CoreDataProperties.h"
#import "EntityPushNotification.h"
#import "PushNotification.h"
#import "PushNotificationProvider.h"
#import "PushNotificationResponder.h"
#import "AWARERotationOM+CoreDataClass.h"
#import "AWARERotationOM+CoreDataProperties.h"
#import "EntityRotation+CoreDataProperties.h"
#import "EntityRotation.h"
#import "Rotation.h"
#import "EntityScreen+CoreDataProperties.h"
#import "EntityScreen.h"
#import "Screen.h"
#import "EntitySignificantMotion+CoreDataClass.h"
#import "EntitySignificantMotion+CoreDataProperties.h"
#import "SignificantMotion.h"
#import "EntityTimezone+CoreDataProperties.h"
#import "EntityTimezone.h"
#import "Timezone.h"
#import "LocationVisit.h"
#import "EntityLocationVisit+CoreDataProperties.h"
#import "EntityLocationVisit.h"
#import "MobileWiFi.h"
#import "WiFiDeviceClient.h"
#import "WiFiManager.h"
#import "WiFiNetwork.h"
#import "EntitySensorWifi+CoreDataClass.h"
#import "EntitySensorWifi+CoreDataProperties.h"
#import "EntityWifi+CoreDataProperties.h"
#import "EntityWifi.h"
#import "SensorWifi.h"
#import "Wifi.h"
#import "ESM.h"
#import "EntityESM+CoreDataClass.h"
#import "EntityESM+CoreDataProperties.h"
#import "EntityESMAnswer+CoreDataProperties.h"
#import "EntityESMAnswer.h"
#import "EntityESMAnswerHistory+CoreDataClass.h"
#import "EntityESMAnswerHistory+CoreDataProperties.h"
#import "EntityESMSchedule+CoreDataClass.h"
#import "EntityESMSchedule+CoreDataProperties.h"
#import "ESMItem.h"
#import "ESMSchedule.h"
#import "ESMScheduleManager.h"
#import "BaseESMView.h"
#import "ESMAudioView.h"
#import "ESMCheckBoxView.h"
#import "ESMClockLineView.h"
#import "ESMClockTimePickerView.h"
#import "ESMDateTimePickerView.h"
#import "ESMLikertScaleView.h"
#import "ESMNumberView.h"
#import "ESMPAMView.h"
#import "PamSchema.h"
#import "ESMPictureView.h"
#import "ESMQuickAnswerView.h"
#import "ESMRadioView.h"
#import "ESMScaleView.h"
#import "ESMFreeTextView.h"
#import "ESMVideoView.h"
#import "ESMWebView.h"
#import "ESMScrollViewController.h"
#import "AWAREHealthKit.h"
#import "AWAREHealthKitCategory.h"
#import "AWAREHealthKitQuantity.h"
#import "AWAREHealthKitWorkout.h"
#import "EntityHealthKitCategory+CoreDataClass.h"
#import "EntityHealthKitCategory+CoreDataProperties.h"
#import "EntityHealthKitCategorySleep+CoreDataClass.h"
#import "EntityHealthKitCategorySleep+CoreDataProperties.h"
#import "EntityHealthKitQuantity+CoreDataClass.h"
#import "EntityHealthKitQuantity+CoreDataProperties.h"
#import "EntityHealthKitQuantityHR+CoreDataClass.h"
#import "EntityHealthKitQuantityHR+CoreDataProperties.h"
#import "EntityHealthKitWorkout+CoreDataClass.h"
#import "EntityHealthKitWorkout+CoreDataProperties.h"
#import "AmbientNoise.h"
#import "AudioAnalysis.h"
#import "EntityAmbientNoise+CoreDataClass.h"
#import "EntityAmbientNoise+CoreDataProperties.h"
#import "EZAudio.h"
#import "EZAudioDevice.h"
#import "EZAudioDisplayLink.h"
#import "EZAudioFFT.h"
#import "EZAudioFile.h"
#import "EZAudioFloatConverter.h"
#import "EZAudioFloatData.h"
#import "EZAudioiOS.h"
#import "EZAudioOSX.h"
#import "EZAudioPlayer.h"
#import "EZAudioPlot.h"
#import "EZAudioPlotGL.h"
#import "EZAudioUtilities.h"
#import "EZMicrophone.h"
#import "EZOutput.h"
#import "EZPlot.h"
#import "EZRecorder.h"
#import "TPCircularBuffer.h"
#import "Conversation.h"
#import "EntityConversation+CoreDataClass.h"
#import "EntityConversation+CoreDataProperties.h"
#import "EntityIOSActivityRecognition+CoreDataClass.h"
#import "EntityIOSActivityRecognition+CoreDataProperties.h"
#import "IOSActivityRecognition.h"
#import "EntityIOSPedometer+CoreDataClass.h"
#import "EntityIOSPedometer+CoreDataProperties.h"
#import "Pedometer.h"

FOUNDATION_EXPORT double AWAREFrameworkVersionNumber;
FOUNDATION_EXPORT const unsigned char AWAREFrameworkVersionString[];

