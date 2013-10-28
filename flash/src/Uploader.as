package
{
    import com.*;
	import com.errors.*;
	import com.events.*

    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.ProgressEvent;
    import flash.external.ExternalInterface;
    import flash.system.Security;
    import flash.utils.*;

    [SWF(width='500', height='500')]
    public class Uploader extends Sprite
    {
        public static var uid:String;

        private var jsReciver:String = "Uploader.reciver";

        public static var compFactory:ComponentFactory;

        /**
         * Main constructor for the Plupload class.
         */
        public function Uploader()
        {
            if (stage) {
                _init();
            } else {
                addEventListener(Event.ADDED_TO_STAGE, _init);
            }
        }


        /**
         * Initialization event handler.
         *
         * @param e Event object.
         */
        private function _init(e:Event = null):void
        {
            removeEventListener(Event.ADDED_TO_STAGE, _init);

            // Allow scripting on swf loaded from another domain
			Security.allowDomain("*");

            // Align and scale stage
            stage.align = StageAlign.TOP_LEFT;
            stage.scaleMode = StageScaleMode.EXACT_FIT;

            var params:Object = stage.loaderInfo.parameters;

            // Setup id
            Uploader.uid = Utils.sanitize(params["uid"]);

            // Event dispatcher
            if (params.hasOwnProperty("jsreciver") && /^[\w\.]+$/.test(params["jsreciver"])) {
                jsReciver = params["jsreciver"];
            }

            //ExternalInterface.marshallExceptions = true; // propagate AS exceptions to JS and vice-versa
            ExternalInterface.addCallback('exec', exec);

            // initialize component factory
            Uploader.compFactory = new ComponentFactory;

			_fireEvent(Uploader.uid + "::Ready");
        }


        public function exec(uid:String, compName:String, action:String, args:* = null) : *
        {
            // Uploader.log([uid, compName, action, args]);

            uid = Utils.sanitize(uid); // make it safe

            var comp:* = Uploader.compFactory.get(uid);

            // WebUploader.log([compName, action]);

            try {
                // initialize corresponding com
                if (!comp) {
                    comp = Uploader.compFactory.create(this, uid, compName);
                }

                // execute the action if available
                if (comp.hasOwnProperty(action)) {
					var ret:* = comp[action].apply(comp, args as Array);
					
					Uploader.log([uid, compName, action, args, ret]);
                    return ret;
                } else {
                    _fireEvent(uid + "::Exception", { name: "RuntimeError", code: RuntimeError.NOT_SUPPORTED_ERR });
                }

            } catch(err:*) { // re-route exceptions thrown by components (TODO: check marshallExceptions feature)
                _fireEvent(uid + "::Exception", { name: getQualifiedClassName(err).replace(/^[^:*]::/, ''), code: err.errorID });
            }
        }


        /**
         * Intercept component events and do some operations if required
         *
         * @param uid String unique identifier of the component throwing the event
         * @param e mixed Event object
         * @param exType String event type in WebUploader format
         */
        public function onComponentEvent(uid:String, e:*, exType:String) : void
        {
            var evt:Object = {};

            switch (e.type)
            {
                case ProgressEvent.PROGRESS:
                case OProgressEvent.PROGRESS:
                    evt.loaded = e.bytesLoaded;
                    evt.total = e.bytesTotal;
                    break;
            }

            evt.type = [uid, exType].join('::');
			_fireEvent(evt, e.hasOwnProperty('data') ? e.data : null);
        }



        /**
         * Fires an event from the flash movie out to the page level JS.
         *
         * @param uid String unique identifier of the component throwing the event
         * @param type Name of event to fire.
         * @param obj Object with optional data.
         */
        private function _fireEvent(evt:*, obj:Object = null):void {
            try {
				ExternalInterface.call(jsReciver, evt, obj);
            } catch(err:*) {
				Uploader.log(["Exception", { name: 'RuntimeError', message: 4 } ]);
                //_fireEvent("Exception", { name: 'RuntimeError', message: 4 });

                // throwing an exception would be better here
            }
        }


        public static function log(obj:*) : void {
            ExternalInterface.call('console.log', obj);
        }

    }
}