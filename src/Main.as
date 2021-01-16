package {

    import snooker.Game;
    import flash.display.Sprite;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    
    /**
     * ...
     * @author 1
     */
    [SWF(width = 1220, height = 580)]
    public class Main extends Sprite {
        
        public function Main() {
            if (stage)
                init();
            else
                addEventListener(Event.ADDED_TO_STAGE, init);
        }
        
        private function init(e: Event = null): void {
            stage.scaleMode = StageScaleMode.NO_SCALE;
            
            var game: Game = new Game();

            game.setGameAreaSize(stage.stageWidth, stage.stageHeight);
            addChild(game);

            game.start();
        }
        
    }
    
}