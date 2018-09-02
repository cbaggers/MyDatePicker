using Uno;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Scripting;

namespace Plinge
{
	[Require("Source.Include", "UIKit/UIKit.h")]
	[Require("Source.Include", "iOS/Helpers.h")]
	extern(iOS) class UIControlEvent : IDisposable
	{
		public static IDisposable AddAllTouchEventsCallback(ObjC.Object uiControl, Action<ObjC.Object, ObjC.Object> handler)
		{
			return new UIControlEvent(uiControl, handler, extern<int>"(int)UIControlEventAllTouchEvents");
		}

		public static IDisposable AddValueChangedCallback(ObjC.Object uiControl, Action<ObjC.Object, ObjC.Object> handler)
		{
			return new UIControlEvent(uiControl, handler, extern<int>"(int)UIControlEventValueChanged");
		}

		public static IDisposable AddAllEditingEventsCallback(ObjC.Object uiControl, Action<ObjC.Object, ObjC.Object> handler)
		{
			return new UIControlEvent(uiControl, handler, extern<int>"(int)UIControlEventAllEditingEvents");
		}

		ObjC.Object _handle;
		ObjC.Object _uiControl;
		readonly int _type;

		UIControlEvent(ObjC.Object uiControl, Action<ObjC.Object, ObjC.Object> handler, int type)
		{
			_handle = Create(uiControl, handler, type);
			_uiControl = uiControl;
			_type = type;
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object Create(ObjC.Object uiControl, Action<ObjC.Object, ObjC.Object> handler, int type)
		@{
			UIControlEventHandler* h = [[UIControlEventHandler alloc] init];
			[h setCallback:handler];
			::UIControl* control = (::UIControl*)uiControl;
			[control addTarget:h action:@selector(action:forEvent:) forControlEvents:(UIControlEvents)type];
			return h;
		@}

		void IDisposable.Dispose()
		{
			RemoveHandler(_uiControl, _handle, _type);
			_handle = null;
			_uiControl = null;
		}

		[Foreign(Language.ObjC)]
		static void RemoveHandler(ObjC.Object uiControl, ObjC.Object eventHandler, int type)
		@{
			UIControlEventHandler* h = (UIControlEventHandler*)eventHandler;
			::UIControl* control = (::UIControl*)uiControl;
			[control removeTarget:h action:@selector(action:forEvent:) forControlEvents:(UIControlEvents)type];
		@}

	}

    static class SDateTimeConverterHelpers
    {
        const long DotNetTicksInJsTick = 10000L;
        const long UnixEpochInDotNetTicks = 621355968000000000L;

        public static DateTime ConvertDateToDateTime(Fuse.Scripting.Context context, Fuse.Scripting.Object date)
        {
            var jsTicks = (long)(double)context.Wrap(date.CallMethod(context, "getTime"));
            var dotNetTicksRelativeToUnixEpoch = jsTicks * DotNetTicksInJsTick;
            var dotNetTicks = dotNetTicksRelativeToUnixEpoch + UnixEpochInDotNetTicks;

            return new DateTime(dotNetTicks, DateTimeKind.Utc);
        }

        public static object ConvertDateTimeToJSDate(Fuse.Scripting.Context context, DateTime dt, Fuse.Scripting.Function dateCtor)
        {
            // TODO: This assumes dt's `Kind` is set to `Utc`. The `Ticks` value may have to be adjusted if `Kind` is `Local` or `Unspecified`.
            //  Currently we don't support other `Kind`'s than `Utc`, but when we do, this code should be updated accordingly.
            //  Something like: `if (dt.Kind != DateTimeKind.Utc) { dt = dt.ToUniversalTime(); }`
            var dotNetTicks = dt.Ticks;
            var dotNetTicksRelativeToUnixEpoch = dotNetTicks - UnixEpochInDotNetTicks;
            var jsTicks = dotNetTicksRelativeToUnixEpoch / DotNetTicksInJsTick;

            return dateCtor.Call(context, (double)jsTicks);
        }
    }

	extern(Android) internal static class DateTimeConverterHelpers
	{
		const long DotNetTicksInMs = 10000L;
		const long UnixEpochInDotNetTicks = 621355968000000000L;

		public static DateTime ConvertMsSince1970InUtcToDateTime(long msSince1970InUtc)
		{
			var dotNetTicksRelativeToUnixEpoch = msSince1970InUtc * DotNetTicksInMs;
			var dotNetTicks = dotNetTicksRelativeToUnixEpoch + UnixEpochInDotNetTicks;

			return new DateTime(dotNetTicks, DateTimeKind.Utc);
		}

		public static long ConvertDateTimeToMsSince1970InUtc(DateTime dt)
		{
			dt = dt.ToUniversalTime();

			var dotNetTicks = dt.Ticks;
			var dotNetTicksRelativeToUnixEpoch = dotNetTicks - UnixEpochInDotNetTicks;
			var msSince1970InUtc = dotNetTicksRelativeToUnixEpoch / DotNetTicksInMs;

			return msSince1970InUtc;
		}
	}

    extern(iOS) internal static class DateTimeConverterHelpers
    {
        const long DotNetTicksInSecond = 10000000L;
        const long UnixEpochInDotNetTicks = 621355968000000000L;

        public static DateTime ConvertNSDateToDateTime(ObjC.Object date)
        {
            var secondsSince1970InUtc = (long)NSDateToSecondsSince1970InUtc(date);

            var dotNetTicksRelativeToUnixEpoch = (long)secondsSince1970InUtc * DotNetTicksInSecond;
            var dotNetTicks = dotNetTicksRelativeToUnixEpoch + UnixEpochInDotNetTicks;

            return new DateTime(dotNetTicks, DateTimeKind.Utc);
        }

        public static ObjC.Object ConvertDateTimeToNSDate(DateTime dt)
        {
            dt = dt.ToUniversalTime();

            var dotNetTicks = dt.Ticks;
            var dotNetTicksRelativeToUnixEpoch = dotNetTicks - UnixEpochInDotNetTicks;
            var secondsSince1970InUtc = dotNetTicksRelativeToUnixEpoch / DotNetTicksInSecond;

            return SecondsSince1970InUtcToNSDate((double)secondsSince1970InUtc);
        }

        [Foreign(Language.ObjC)]
        public static double NSDateToSecondsSince1970InUtc(ObjC.Object date)
        @{
            return [date timeIntervalSince1970];
        @}

        [Foreign(Language.ObjC)]
        public static ObjC.Object SecondsSince1970InUtcToNSDate(double secondsSince1970InUtc)
        @{
            return [NSDate dateWithTimeIntervalSince1970:secondsSince1970InUtc];
        @}

        [Foreign(Language.ObjC)]
        public static ObjC.Object ReconstructUtcDate(ObjC.Object date)
        @{
            if (!date)
                return [NSDate dateWithTimeIntervalSince1970:0];

            // Reconstruct the same date in UTC without time components
            NSCalendar *utcCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
            [utcCalendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

            NSDateComponents *components = [utcCalendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];

            NSDateComponents *utcComponents = [[NSDateComponents alloc] init];
            [utcComponents setYear:[components year]];
            [utcComponents setMonth:[components month]];
            [utcComponents setDay:[components day]];

            return [utcCalendar dateFromComponents:utcComponents];
        @}

        [Foreign(Language.ObjC)]
        public static ObjC.Object ReconstructUtcTime(ObjC.Object date)
        @{
            if (!date)
                return [NSDate dateWithTimeIntervalSince1970:0];

            // Reconstruct the same date in UTC without date components
            NSCalendar *utcCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
            [utcCalendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

            NSDateComponents *components = [utcCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date];

            NSDateComponents *utcComponents = [[NSDateComponents alloc] init];
            [utcComponents setYear:1970];
            [utcComponents setMonth:1];
            [utcComponents setDay:1];
            [utcComponents setHour:[components hour]];
            [utcComponents setMinute:[components minute]];

            return [utcCalendar dateFromComponents:utcComponents];
        @}
    }
}
