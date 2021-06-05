package snooker {
    
    import snooker.images.ImageAssets;
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.Graphics;
    import flash.display.Shape;
    import flash.display.Sprite;
    import flash.display.StageQuality;
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.events.MouseEvent;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFieldType;
    import flash.text.TextFormat;
    import flash.text.TextFormatAlign;
    import flash.utils.getTimer;
    import spark.primitives.Rect;
    
    public final class Game extends Sprite {
        
        // The following coordinate systems used in the game are described below:
        // Sprite coordinates: The coordinate system used by the Flash Player. This is dependent on the game's
        // run-time resolution.
        // Resolution-independent coordinates: This is same as sprite coordinates but with both x and y values divided
        // by the resolution scaling factor. This is independent of the game's run-time resolution. The origin is the
        // same as in sprite coordinates, i.e. the top left corner of the display object.
        // Game engine coordinates: Same as resolution independent coordinates, but with the origin at a different
        // position (the top left corner of the table, cushions excluded)
        
        /**
         * Text used in the game.
         */
        private static var s_gameText: Vector.<String> = new <String>[
            // Text for game info display
            /*00*/ "Score:",
            /*01*/ "This break:",
            /*02*/ "Best break:",
            /*03*/ "Current colour:",
            /*04*/ "Click/ENTER to confirm.",
            /*05*/ "Use left/right arrow keys\nto select an option.",
            /*06*/ "Use left/right arrow keys\nto select a colour.",
            /*07*/ "Use the arrow keys to move\nthe cue ball.",
            /*08*/ "Use the mouse or left/right\narrow keys to aim the cue.",
            /*09*/ "Adjust the shot power by\nmoving the mouse up/down\nor by using up/down arrow\nkeys.",
            /*10*/ "Click/ENTER to shoot.",
            /*11*/ "BACKSPACE to return to\naiming mode.",
            /*12*/ "Foul!",
            /*13*/ "Request replay?",
            /*14*/ "YES",
            /*15*/ "NO",
            /*16*/ "End of frame",
            /*17*/ "End of match",
            /*18*/ "$1\nwins the frame!",
            /*19*/ "$1\nwins the match!",
            /*20*/ "Click/ENTER to start\nthe next frame.",
            /*21*/ "Click/ENTER to start\na new match.",
            /*22*/ "Tiebreaker",
            /*23*/ "Breaking player:",
            
            // Text for match options menu
            /*24*/ "Match options",
            /*25*/ "Match type:",
            /*26*/ "Single player",
            /*27*/ "Two player",
            /*28*/ "Player 1 name:",
            /*29*/ "Player 2 name:",
            /*30*/ "First frame opener:",
            /*31*/ "Player 1",
            /*32*/ "Player 2",
            /*33*/ "CPU",
            /*34*/ "Frames to win:",
            /*35*/ "Start match",
        ];

        private static const BUTTON_SINGLE_PLAYER: int = 0;
        private static const BUTTON_TWO_PLAYER: int = 1;
        private static const BUTTON_FIRST_FRAME_P1: int = 2;
        private static const BUTTON_FIRST_FRAME_P2: int = 3;
        private static const BUTTON_START_MATCH: int = 4;
        
        // These are the clickable areas (buttons) in the game's match options menu.
        // Each button is defined as a rectangle.
        // All coordinates are in the resolution-independent coordinate system.
        // The button at index 'i' in this array is defined as the one whose x value is stored at index i*4.
        private static var s_matchMenuButtonRanges: Vector.<Rectangle> = new <Rectangle>[
            new Rectangle(1125.0, 449.0, 26.0, 26.0),    // 0: Match mode - option 'Single player'
            new Rectangle(1396.0, 449.0, 26.0, 26.0),    // 1: Match mode - option 'Two player'
            new Rectangle(1125.0, 698.0, 26.0, 26.0),    // 2: First frame opening - option 'Player 1'
            new Rectangle(1396.0, 698.0, 26.0, 26.0),    // 3: First frame opening - option 'Player 2'
            new Rectangle(1125.0, 787.0, 256.0, 50.0),   // 4: Start match
        ];
        
        // Text formats used for drawing text in the game.
        private static var s_playerNameTextFormat: TextFormat = new TextFormat("Trebuchet MS", 32, 0xAA0000, false, true);
        private static var s_playerScoreTextFormat: TextFormat = new TextFormat("Trebuchet MS", 88, 0x008500, true, true);
        private static var s_breakScoreTextFormat: TextFormat = new TextFormat("Trebuchet MS", 32, 0x008500, false, true);
        private static var s_playerFrameTextFormat: TextFormat = new TextFormat("Trebuchet MS", 28, 0x000085, false, true);
        private static var s_infoTextFormat1: TextFormat = new TextFormat("Trebuchet MS", 34, 0x000000, true, false);
        private static var s_infoTextFormat2: TextFormat = new TextFormat("Trebuchet MS", 30, 0x000000, false, false);
        private static var s_infoTextFormat3: TextFormat = new TextFormat("Trebuchet MS", 26, 0x000000, false, false);
        private static var s_infoTextFormat4: TextFormat = new TextFormat("Trebuchet MS", 30, 0x880000, false, true);
        private static var s_infoTextFormat5: TextFormat = new TextFormat("Trebuchet MS", 34, 0x000066, true, false);
        
        // Text formats used in the match options menu
        private static var s_menuTextFormat1: TextFormat = new TextFormat("Trebuchet MS", 40, 0x008500, true, true);
        private static var s_menuTextFormat2: TextFormat = new TextFormat("Trebuchet MS", 26, 0x000000, false, false);
        private static var s_menuTextFormat3: TextFormat = new TextFormat("Trebuchet MS", 26, 0x000000, false, true);
        private static var s_menuTextFormat4: TextFormat = new TextFormat("Trebuchet MS", 30, 0x000000, true, false);
        private static var s_menuInputTextFormat: TextFormat = new TextFormat("Trebuchet MS", 26, 0x333333, false, true);

        private static const DRAW_TABLE_STATE_MASK: int =
            1 << GameState.CUEBALL_IN_HAND
            | 1 << GameState.CUE_AIM
            | 1 << GameState.CUE_SHOT_POWER
            | 1 << GameState.CUE_SHOOT
            | 1 << GameState.SHOT_IN_PROGRESS;

        private static const DRAW_CUE_STATE_MASK: int =
            1 << GameState.CUE_AIM
            | 1 << GameState.CUE_SHOT_POWER
            | 1 << GameState.CUE_SHOOT;

        private static const DRAW_INFO_STATE_MASK: int =
            1 << GameState.CHOOSE_FOUL_PLAYER
            | 1 << GameState.CHOOSE_COLOUR
            | 1 << GameState.CHOOSE_TIE_PLAYER;

        // Display names of the two players
        private var m_playerName1: String = "Player 1";
        private var m_playerName2: String = "Player 2";
        
        // Bitmaps used in the game
        private var m_ballSpriteSheet: BitmapData;
        private var m_tableBackBitmapData: BitmapData;
        private var m_cueBitmapData: BitmapData;
        private var m_infoBackBitmapData: BitmapData;
        private var m_matchMenuBackBitmapData: BitmapData;
        
        // The main game bitmap
        private var m_gameAreaBitmapData: BitmapData;
        
        // Square size in the ball spritesheet
        private var m_ballSpriteSheetSquare: int;
        
        // The resolution scaling factor for the game which determines the game area size. Can be from 0 to 1.
        // (1 is full size [2510x1194], 0.5 is default)
        private var m_resolutionFactor: Number = 0.5;
        
        // True when the game is started
        private var m_gameStarted: Boolean = false;
        
        // The game engine
        private var m_engine: GameEngine;
        
        // The CPU player (for a single player game).
        private var m_cpuPlayer: CPUPlayer;
        // True if single-player mode is enabled.
        private var m_isSinglePlayerGame: Boolean;
        
        // True when the CPU player is playing
        private var m_cpuPlayerEngaged: Boolean = false;
        // True when the CPU player's shot has been executed.
        private var m_cpuPlayerShotExecuted: Boolean = false;
        
        // A timestamp set when the CPU player has selected its shot (used for execution delay)
        private var m_cpuPlayerReadyTimeStamp: Number = 0;
        
        // Previous frame game state
        private var m_lastGameState: int;
        
        // True if key press detected in current frame
        private var m_keyPressDetected: Boolean;
        
        // Temporary objects
        private var m_pointObject: Point;
        private var m_rectObject: Rectangle;
        private var m_transformMatrix: Matrix;
        
        // Previous frame mouse position (for detecting mouse moves)
        // This is in sprite coordinates.
        private var m_lastMouseX: Number;
        private var m_lastMouseY: Number;
        
        // Temporary Shape and TextField objects used for drawing vector graphics and text in the game.
        // _textField1, _textField2 and _textField3 are used for left, centre and right aligned text
        // respectively.
        private var m_tempShape: Shape;
        private var m_tempTextField1: TextField;
        private var m_tempTextField2: TextField;
        private var m_tempTextField3: TextField;
        
        // Timestamp for the current frame.
        private var m_timeStamp: Number = 0;
        
        // m_matchMenuEnabled: The match options menu is engaged.
        // m_matchMenuChanged: A change ocured in the match menu which may require a redraw (this excludes changes
        // in the input text fields, which are updated independently by the Flash renderer)
        private var m_matchMenuEnabled: Boolean;
        private var m_matchMenuChanged: Boolean;
        
        // These TextField objects are used for user input of text in the match options menu.
        private var m_menuInputField_pName1: TextField;         // Player 1 name
        private var m_menuInputField_pName2: TextField;         // Player 2 name
        private var m_menuInputField_targetFrames: TextField;   // Frames to win
        
        // A flag that is set when the 'Start match' button is clicked in the match options menu.
        // This is used in a single player game to alert the CPU player if it is set to open the first
        // frame (since there is no change in the game engine's state when the button is clicked)
        private var m_matchBegin: Boolean;
        
        public function Game() {
            _init();
        }
        
        private function _init(): void {
            m_pointObject = new Point();
            m_rectObject = new Rectangle();
            m_transformMatrix = new Matrix();
            m_tempShape = new Shape();
            m_tempTextField1 = new TextField();
            m_tempTextField2 = new TextField();
            m_tempTextField3 = new TextField();
            m_tempTextField1.autoSize = TextFieldAutoSize.LEFT;
            m_tempTextField2.autoSize = TextFieldAutoSize.CENTER;
            m_tempTextField3.autoSize = TextFieldAutoSize.RIGHT;
            
            // Initialize the input text fields for the match options menu
            
            m_menuInputField_pName1 = new TextField();
            m_menuInputField_pName2 = new TextField();
            m_menuInputField_targetFrames = new TextField();
            m_menuInputField_pName1.type = TextFieldType.INPUT;
            m_menuInputField_pName2.type = TextFieldType.INPUT;
            m_menuInputField_targetFrames.type = TextFieldType.INPUT;
            m_menuInputField_pName1.autoSize = TextFieldAutoSize.LEFT;
            m_menuInputField_pName2.autoSize = TextFieldAutoSize.LEFT;
            m_menuInputField_targetFrames.autoSize = TextFieldAutoSize.LEFT;
            m_menuInputField_pName1.defaultTextFormat = s_menuInputTextFormat;
            m_menuInputField_pName2.defaultTextFormat = s_menuInputTextFormat;
            m_menuInputField_targetFrames.defaultTextFormat = s_menuInputTextFormat;
            
            // The following restrictions are currently set on the input fields:
            // Player 1 name/Player 2 name: Max 12 characters
            // Frames to win: Numbers only, max 2 characters
            m_menuInputField_pName1.maxChars = 12;
            m_menuInputField_pName2.maxChars = 12;
            m_menuInputField_targetFrames.maxChars = 2;
            m_menuInputField_targetFrames.restrict = "0-9";
            
            m_menuInputField_pName1.text = "Player 1";
            m_menuInputField_pName2.text = "Player 2";
            m_menuInputField_targetFrames.text = "1";
            
            m_menuInputField_pName1.x = 1130;
            m_menuInputField_pName2.x = 1130;
            m_menuInputField_targetFrames.x = 1130;
            m_menuInputField_pName1.y = 504;
            m_menuInputField_pName2.y = 566;
            m_menuInputField_targetFrames.y = 628;
        }
        
        /**
         * Starts the game. (The object must be added to the stage first)
         */
        public function start(): void {
            if (!stage)
                throw new Error("Cannot start the game until the Game object is added to the stage.");
           
            _initGameSetup();

            m_engine = new GameEngine();
            m_cpuPlayer = new CPUPlayer(m_engine);
            m_isSinglePlayerGame = true;

            _drawTable();
            _drawInfoDisplay();

            addEventListener(Event.ENTER_FRAME, _onEnterFrame);
            addEventListener(MouseEvent.CLICK, _onClick);
            stage.addEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
            stage.addEventListener(KeyboardEvent.KEY_UP, _onKeyUp);
            
            // Scale the text input fields
            var rf: Number = m_resolutionFactor;
            m_menuInputField_pName1.scaleX = m_menuInputField_pName1.scaleY = rf;
            m_menuInputField_pName1.x *= rf;
            m_menuInputField_pName1.y *= rf;
            m_menuInputField_pName2.scaleX = m_menuInputField_pName2.scaleY = rf;
            m_menuInputField_pName2.x *= rf;
            m_menuInputField_pName2.y *= rf;
            m_menuInputField_targetFrames.scaleX = m_menuInputField_targetFrames.scaleY = rf;
            m_menuInputField_targetFrames.x *= rf;
            m_menuInputField_targetFrames.y *= rf;
            
            m_lastGameState = m_engine.gameState;
            m_gameStarted = true;

            _toggleMatchMenuEnabled();
        }
        
        private function _initGameSetup(): void {
            var matrix: Matrix = m_transformMatrix;
            var rf: Number = m_resolutionFactor;
            var gameAreaPadding: int = int(240 * rf);
            
            // Generate ball sprite sheet
            _generateBalls();
            
            // Table background
            var fullTableBackBitmapData: BitmapData = (new ImageAssets.__TableBack() as Bitmap).bitmapData;
            m_tableBackBitmapData = new BitmapData(int(fullTableBackBitmapData.width * rf) + gameAreaPadding, int(fullTableBackBitmapData.height * rf) + gameAreaPadding, false, 0xFFFFFFFF);
            matrix.a = matrix.d = rf;
            matrix.b = matrix.c = 0;
            matrix.tx = matrix.ty = 110 * rf;
            m_tableBackBitmapData.drawWithQuality(fullTableBackBitmapData, matrix, null, null, null, true, StageQuality.BEST);
            fullTableBackBitmapData.dispose();
            
            // Cue stick
            var fullCueBitmapData: BitmapData = (new ImageAssets.__CueStick() as Bitmap).bitmapData;
            m_cueBitmapData = new BitmapData(Math.ceil(fullCueBitmapData.width * rf), Math.ceil(fullCueBitmapData.height * rf), true, 0);
            matrix.a = matrix.d = rf;
            matrix.b = matrix.c = matrix.tx = matrix.ty = 0;
            m_cueBitmapData.drawWithQuality( fullCueBitmapData, matrix, null, null, null, true, StageQuality.BEST);
            fullCueBitmapData.dispose();
            
            // Info background
            var fullInfoBackBitmapData: BitmapData = (new ImageAssets.__InfoBack() as Bitmap).bitmapData;
            m_infoBackBitmapData = new BitmapData(Math.ceil(fullInfoBackBitmapData.width * rf), Math.ceil(fullInfoBackBitmapData.height * rf), false, 0xFFFFFFFF);
            matrix.a = matrix.d = rf;
            matrix.b = matrix.c = matrix.tx = matrix.ty = 0;
            m_infoBackBitmapData.drawWithQuality(fullInfoBackBitmapData, matrix, null, null, null, true, StageQuality.BEST);
            fullInfoBackBitmapData.dispose();
            
            // Match options menu background
            var fullMatchMenuBackBitmapData: BitmapData = (new ImageAssets.__MenuBack() as Bitmap).bitmapData;
            matrix.a = matrix.d = rf;
            matrix.b = matrix.c = matrix.tx = matrix.ty = 0;
            m_matchMenuBackBitmapData = new BitmapData(Math.ceil(fullMatchMenuBackBitmapData.width * rf), Math.ceil(fullMatchMenuBackBitmapData.height * rf), true, 0);
            m_matchMenuBackBitmapData.drawWithQuality(fullMatchMenuBackBitmapData, matrix, null, null, null, true, StageQuality.BEST);
            fullMatchMenuBackBitmapData.dispose();

            // Create the game area...
            m_gameAreaBitmapData = new BitmapData(m_tableBackBitmapData.width + m_infoBackBitmapData.width, m_tableBackBitmapData.height, false, 0xFFFFFFFF);
            var gameAreaBitmap: Bitmap = new Bitmap(m_gameAreaBitmapData);
            gameAreaBitmap.x = 0;
            gameAreaBitmap.y = 0;
            addChild(gameAreaBitmap);
        }
        
        public function setGameAreaSize(width: int, height: int): void {
            if (m_gameStarted)
                throw new ArgumentError("Game area size cannot be changed once the game is started.");

            var rf1: Number = width / 2510;
            var rf2: Number = height / 1194;

            if (rf1 > rf2)
                rf1 = rf2;

            if (rf1 <= 0 || rf1 > 1)
                throw new ArgumentError("Invaild game area size.");

            m_resolutionFactor = rf1;
        }
        
        /**
         * Generates the sprite sheet for the snooker balls.
         */
        private function _generateBalls(): void {
            // Create instances of the embedded ball images
            var ballsBitmapData: Vector.<BitmapData> = new <BitmapData>[
                (new ImageAssets.__WhiteBall() as Bitmap).bitmapData,
                (new ImageAssets.__RedBall() as Bitmap).bitmapData,
                (new ImageAssets.__YellowBall() as Bitmap).bitmapData,
                (new ImageAssets.__GreenBall() as Bitmap).bitmapData,
                (new ImageAssets.__BrownBall() as Bitmap).bitmapData,
                (new ImageAssets.__BlueBall() as Bitmap).bitmapData,
                (new ImageAssets.__PinkBall() as Bitmap).bitmapData,
                (new ImageAssets.__BlackBall() as Bitmap).bitmapData,
            ];
            
            // Calculate the ball's sprite square based on the resolution factor
            m_ballSpriteSheetSquare = int(Math.ceil(m_resolutionFactor * 31));

            var matrix: Matrix = m_transformMatrix;
            matrix.a = matrix.d = m_resolutionFactor;
            matrix.b = matrix.c = 0;
            matrix.tx = 0.5 * m_ballSpriteSheetSquare - 15.5 * m_resolutionFactor;
            
            // Draw the balls...
            m_ballSpriteSheet = new BitmapData(m_ballSpriteSheetSquare * 8, m_ballSpriteSheetSquare, true, 0);
            for (var i: int = 0; i < 8; i++) {
                m_ballSpriteSheet.drawWithQuality(ballsBitmapData[i], matrix, null, null, null, true, StageQuality.BEST);
                matrix.tx += m_ballSpriteSheetSquare;
                ballsBitmapData[i].dispose();
            }
        }
        
        /**
         * Listener for Event.ENTER_FRAME event.
         */
        private function _onEnterFrame(evt: Event): void {
            m_timeStamp = getTimer();

            if (m_matchMenuEnabled) {
                if (m_matchMenuChanged) {
                    _drawMatchMenu();
                    m_matchMenuChanged = false;
                }
            }
            else {
                _checkMouseMove();
                m_engine.update();
                _handleCPUPlayer();
                _drawGameArea();

                m_lastGameState = m_engine.gameState;
                m_keyPressDetected = false;
                m_matchBegin = false;
            }
        }
        
        /**
         * Listener for KeyboardEvent.KEY_DOWN event.
         */
        private function _onKeyDown(evt: KeyboardEvent): void {
            if (m_matchMenuEnabled || m_cpuPlayerEngaged)
                return;

            m_engine.keyPress(evt.keyCode, 1);
            m_keyPressDetected = true;
            
            if (m_engine.gameState === GameState.GAME_OVER
                && (evt.keyCode === 13 || evt.keyCode === 108)
                && (m_engine.framesWonPlayer1 === m_engine.targetFrames || m_engine.framesWonPlayer2 === m_engine.targetFrames))
            {
                // Open the match menu when a new match starts
                _toggleMatchMenuEnabled();
            }
        }
        
        /**
         * Listener for KeyboardEvent.KEY_UP event.
         */
        private function _onKeyUp(evt: KeyboardEvent): void {
            if (m_matchMenuEnabled || m_cpuPlayerEngaged)
                return;

            m_engine.keyPress(evt.keyCode, 0);
            m_keyPressDetected = true;
        }
        
        /**
         * Listener for MouseEvent.CLICK event.
         */
        private function _onClick(evt: MouseEvent): void {
            if (m_matchMenuEnabled) {
                // Handle clicks when the match options menu is engaged
                _handleMatchMenuButtonClick(_getClickedMenuButton(mouseX, mouseY));
                return;
            }
            
            if (m_cpuPlayerEngaged)
                return;

            // Consider click as equivalent to Enter key during the game
            m_engine.keyPress(13, 1);   
            m_keyPressDetected = true;

            if (m_engine.gameState === 9
                && (m_engine.framesWonPlayer1 === m_engine.targetFrames || m_engine.framesWonPlayer2 === m_engine.targetFrames))
            {
                // Open the match menu when a new match starts
                _toggleMatchMenuEnabled();
            }
        }
        
        /**
         * Checks if the mouse has been moved in the current frame. If a mouse move is detected, the new mouse
         * coordinates are set to the game engine.
         */
        private function _checkMouseMove(): void {
            if (m_cpuPlayerEngaged)
                return;
                
            var curMouseX: Number = mouseX, curMouseY: Number = mouseY;
            if (curMouseX !== m_lastMouseX || curMouseY !== m_lastMouseY) {
                if (m_lastMouseX >= 0
                    && m_lastMouseY >= 0
                    && m_lastMouseX <= m_gameAreaBitmapData.width
                    && m_lastMouseY <= m_gameAreaBitmapData.height)
                {
                    var rfi: Number = 1 / m_resolutionFactor;
                    m_engine.setMousePosition(curMouseX * rfi - 159.4, curMouseY * rfi - 159.4);
                }

                m_lastMouseX = curMouseX;
                m_lastMouseY = curMouseY;
            }
        }
        
        /**
         * Function for handling the CPU player on every frame, in single player mode.
         */
        private function _handleCPUPlayer(): void {
            if (!m_isSinglePlayerGame)
                return;
                
            var currentState: int = m_engine.gameState;

            if (m_cpuPlayerEngaged) {
                // Keep a delay of 1.5s between engaging the CPU player and shot execution.
                if (m_cpuPlayerShotExecuted) {
                    // Once the shot is executed and the game state is set to shooting (4),
                    // disengage the CPU player to allow input.
                    if (currentState === GameState.CUE_SHOOT)
                        m_cpuPlayerEngaged = false;
                }
                else if (m_timeStamp - m_cpuPlayerReadyTimeStamp >= 1500) {
                    // Shot execution delay is over. Since after the shot selection the game state is
                    // set to 3 (CUE_SHOT_POWER), issue an ENTER key press to shoot.
                    m_engine.keyPress(13, 1);
                    m_cpuPlayerShotExecuted = true;
                }
            }
            else if (m_lastGameState !== currentState || m_matchBegin) {
                if (currentState === GameState.CHOOSE_TIE_PLAYER) {
                    // For single player matches, select the breaking player randomly when a tiebreaker
                    // is called.
                    m_engine.setCurrentPlayer((Math.random() < 0.5) ? 1 : 0);
                }

                if (m_engine.currentPlayer === 1
                    && (
                        currentState === GameState.CUEBALL_IN_HAND
                        || currentState === GameState.CUE_AIM
                        || currentState === GameState.CHOOSE_FOUL_PLAYER
                        || currentState === GameState.CHOOSE_COLOUR
                        || currentState === GameState.CHOOSE_TIE_PLAYER
                    ))
                {
                    // Request the CPU player to select its shot.
                    m_cpuPlayer.selectShot();

                    // If the (human) player committed a foul and the CPU requests a replay, issue an ENTER key press
                    // to the game engine
                    if (m_engine.currentPlayer === 0 && currentState === GameState.CHOOSE_FOUL_PLAYER) {
                        m_engine.keyPress(13, 1);
                        return;
                    }

                    // Engage the CPU player. (This will cause the game to ignore mouse/keyboard input)
                    m_cpuPlayerEngaged = true;
                    m_cpuPlayerShotExecuted = false;
                    m_cpuPlayerReadyTimeStamp = m_timeStamp;
                }
            }
        }
        
        /**
         * Renders the game area on every frame.
         */
        private function _drawGameArea(): void {
            m_gameAreaBitmapData.lock();

            var state: int = m_engine.gameState;

            if (state !== m_lastGameState || ((1 << state) & DRAW_TABLE_STATE_MASK) !== 0)
                _drawTable();

            if (state !== m_lastGameState || (m_keyPressDetected && ((1 << state) & DRAW_INFO_STATE_MASK) !== 0))
                _drawInfoDisplay();

            m_gameAreaBitmapData.unlock();
        }
        
        /**
         * Renders the table, balls and cue stick.
         */
        private function _drawTable(): void {
            var balls: Vector.<Ball> = m_engine.balls;
            var rect: Rectangle = m_rectObject;
            var pt: Point = m_pointObject;
            var rf: Number = m_resolutionFactor;
            var matrix: Matrix = m_transformMatrix;
            var requireCue: Boolean = ((1 << m_engine.gameState) & DRAW_CUE_STATE_MASK) !== 0;
            var cueDirX: Number = m_engine.cueDirX;
            var cueDirY: Number = m_engine.cueDirY;
            
            // Draw the table background
            rect.x = rect.y = 0;
            rect.width = m_tableBackBitmapData.width;
            rect.height = m_tableBackBitmapData.height;
            pt.x = pt.y = 0;
            m_gameAreaBitmapData.copyPixels(m_tableBackBitmapData, rect, pt);
            
            // If the game is in the cue aiming or shooting state, draw the rangefinder.
            if (requireCue && m_engine.gameState !== GameState.CUE_SHOOT && !m_cpuPlayerEngaged)
                _drawRangeFinder();
                
            // Draw the balls
            var ballOffset: Number = 160.4 * rf - 0.5 * m_ballSpriteSheetSquare;
            rect.width = rect.height = m_ballSpriteSheetSquare;
            rect.y = 0;
            for (var i: int = 0, n: int = balls.length; i < n; i++) {
                var ball: Ball = balls[i];
                if (ball.potStatus !== 0)
                    continue;

                rect.x = ball.colour * m_ballSpriteSheetSquare;
                pt.x = ballOffset + ball.x * rf;
                pt.y = ballOffset + ball.y * rf;
                m_gameAreaBitmapData.copyPixels(m_ballSpriteSheet, rect, pt, null, null, true);
            }
            
            // Draw the cue stick if required
            if (requireCue) {
                matrix.a = -cueDirX;
                matrix.b = -cueDirY;
                matrix.c = cueDirY;
                matrix.d = -cueDirX;
                matrix.tx = (m_engine.cueTipDistance * -cueDirX + balls[0].x + 159.4) * rf - 0.5 * m_cueBitmapData.height * cueDirY;
                matrix.ty = (m_engine.cueTipDistance * -cueDirY + balls[0].y + 159.4) * rf + 0.5 * m_cueBitmapData.height * cueDirX;
                rect.x = rect.y = 0;
                rect.width = m_tableBackBitmapData.width;
                rect.height = m_tableBackBitmapData.height;
                m_gameAreaBitmapData.draw(m_cueBitmapData, matrix, null, null, rect, true);
            }
        }
        
        /**
         * Draws the cue rangefinder (displayed when the player is aiming the cue)
         */
        private function _drawRangeFinder(): void {
            var rgStartX: Number = m_engine.balls[0].x;
            var rgStartY: Number = m_engine.balls[0].y;
            var rgEndX: Number;
            var rgEndY: Number;
            var rgDirX: Number = m_engine.cueDirX;
            var rgDirY: Number = m_engine.cueDirY;
            var rf: Number = m_resolutionFactor;
            
            var tempGraphics: Graphics = m_tempShape.graphics;
            tempGraphics.clear();
            
            var rgColour: int;
            if (m_engine.predictedTargetBall !== null)
                rgColour = (m_engine.predictedTargetBall.colour !== m_engine.currentColour) ? 0xEE5555 : 0xCC88FF;
            else
                rgColour = 0xFFAA99;
            
            if (m_engine.predictedTargetBall !== null) {
                // If a target ball is predicted to be hit, draw the cue line upto the target ball and show
                // the predicted direction of the target.
                rgEndX = m_engine.predictedTargetImpactX;
                rgEndY = m_engine.predictedTargetImpactY;
                
                tempGraphics.lineStyle(1, rgColour, 1);
                tempGraphics.drawCircle(
                    (m_engine.predictedTargetBall.x + 159.4) * rf,
                    (m_engine.predictedTargetBall.y + 159.4) * rf,
                    25.2 * rf
                );
                tempGraphics.lineStyle(1, 0xFFAA99, 1);
                tempGraphics.moveTo((rgStartX + 159.4) * rf, (rgStartY + 159.4) * rf);
                tempGraphics.lineTo((rgEndX + 159.4) * rf, (rgEndY + 159.4) * rf);
                
                rgStartX = m_engine.predictedTargetBall.x;
                rgStartY = m_engine.predictedTargetBall.y;
                rgDirX = m_engine.predictedTargetDirX;
                rgDirY = m_engine.predictedTargetDirY;
            }
            
            // Clip the rangefinder line to the boundaries of the table.
            if (rgDirX !== 0) {
                rgEndX = (rgDirX < 0) ? 0 : 1713.1;
                rgEndY = rgStartY + rgDirY * ((rgEndX - rgStartX) / rgDirX);
            }
            if (rgDirX === 0 || rgEndY < 0 || rgEndY > 853.4) {
                rgEndY = (rgDirY < 0) ? 0 : 853.4;
                rgEndX = rgStartX + rgDirX * ((rgEndY - rgStartY) / rgDirY);
            }
            
            if (m_engine.predictedTargetBall !== null) {
                // When showing the target ball direction, limit the length of the direction line.
                var targetDirLimit: Number = 180;
                var rgLenSq: Number = (rgEndX - rgStartX) * (rgEndX - rgStartX) + (rgEndY - rgStartY) * (rgEndY - rgStartY);
                
                if (rgLenSq > targetDirLimit * targetDirLimit) {
                    rgEndX = rgStartX + targetDirLimit * rgDirX;
                    rgEndY = rgStartY + targetDirLimit * rgDirY;
                }
            }
                
            tempGraphics.lineStyle(1, rgColour, 1);
            tempGraphics.moveTo((rgStartX + 159.4) * rf, (rgStartY + 159.4) * rf);
            tempGraphics.lineTo((rgEndX + 159.4) * rf, (rgEndY + 159.4) * rf);
            
            m_gameAreaBitmapData.draw(m_tempShape, null, null, null, null, true);
        }
        
        /**
         * Renders the information display (to the right of the table).
         */
        private function _drawInfoDisplay(): void {
            var rect: Rectangle = m_rectObject;
            var pt: Point = m_pointObject;
            var rf: Number = m_resolutionFactor;
            var matrix: Matrix = m_transformMatrix;
            var textField1: TextField = m_tempTextField1;
            var textField2: TextField = m_tempTextField3;
            var gameState: int = m_engine.gameState;
            
            // Background
            rect.x = int(30 * rf);
            rect.width = int(396 * rf);
            rect.height = int(220 * rf);
            pt.x = int(2060 * rf);
            
            // Use the blue box for the current player's score and the grey box for the other
            // player's score. (When the game ends, show both boxes as grey)
            pt.y = int(72 * rf);
            rect.y = int(((m_engine.currentPlayer === 0 && gameState !== GameState.GAME_OVER) ? 246 : 12) * rf);
            m_gameAreaBitmapData.copyPixels(m_infoBackBitmapData, rect, pt);

            pt.y = int(306 * rf);
            rect.y = int(((m_engine.currentPlayer === 1 && gameState !== GameState.GAME_OVER) ? 246 : 12) * rf);
            m_gameAreaBitmapData.copyPixels(m_infoBackBitmapData, rect, pt);

            // Draw the remaining part of the background
            pt.y = int(544 * rf);
            rect.y = int(484 * rf);
            rect.height = int(574 * rf);
            m_gameAreaBitmapData.copyPixels(m_infoBackBitmapData, rect, pt);
            
            // Background text
            _writeText(s_gameText[0], s_infoTextFormat1, 0, 2100, 200);
            _writeText(s_gameText[0], s_infoTextFormat1, 0, 2100, 434);
            _writeText(s_gameText[1], s_infoTextFormat2, 0, 2100, 560);
            _writeText(s_gameText[2], s_infoTextFormat2, 0, 2100, 602);
            _writeText(s_gameText[3], s_infoTextFormat2, 0, 2100, 694);
            
            // Player names, scores, frames, breaks
            var targetFrameString: String = "/" + m_engine.targetFrames.toString();
            _writeText(m_playerName1, s_playerNameTextFormat, 0, 2090, 88);
            _writeText(m_playerName2, s_playerNameTextFormat, 0, 2090, 322);
            _writeText(m_engine.framesWonPlayer1.toString() + targetFrameString, s_playerFrameTextFormat, 2, 2320, 94);
            _writeText(m_engine.framesWonPlayer2.toString() + targetFrameString, s_playerFrameTextFormat, 2, 2320, 328);
            _writeText(m_engine.scorePlayer1.toString(), s_playerScoreTextFormat, 2, 2320, 154);
            _writeText(m_engine.scorePlayer2.toString(), s_playerScoreTextFormat, 2, 2320, 388);
            _writeText(m_engine.currentBreak.toString(), s_breakScoreTextFormat, 2, 2300, 560);
            _writeText(m_engine.bestBreak.toString(), s_breakScoreTextFormat, 2, 2300, 602)
            
            // Current colour ball
            pt.x = int(2380 * rf);
            pt.y = int(700 * rf);
            rect.x = m_ballSpriteSheetSquare * m_engine.currentColour;
            rect.y = 0;
            rect.width = rect.height = m_ballSpriteSheetSquare;
            m_gameAreaBitmapData.copyPixels(m_ballSpriteSheet, rect, pt, null, null, true);
            
            // State-specific instructions: (only when CPU player is not engaged)
            if (!m_cpuPlayerEngaged) {
                if (gameState === GameState.CUEBALL_IN_HAND) {
                    _writeText(s_gameText[7], s_infoTextFormat3, 1, 2208, 790);
                    _writeText(s_gameText[4], s_infoTextFormat3, 1, 2208, 890);
                }
                else if (gameState === GameState.CUE_AIM) {
                    _writeText(s_gameText[8], s_infoTextFormat3, 1, 2208, 790);
                    _writeText(s_gameText[4], s_infoTextFormat3, 1, 2208, 890);
                }
                else if (gameState === GameState.CUE_SHOT_POWER) {
                    _writeText(s_gameText[9], s_infoTextFormat3, 1, 2208, 790);
                    _writeText(s_gameText[10], s_infoTextFormat3, 1, 2208, 950);
                    _writeText(s_gameText[11], s_infoTextFormat3, 1, 2208, 1000);
                }
                else if (gameState === GameState.CHOOSE_FOUL_PLAYER) {
                    _writeText(s_gameText[12], s_infoTextFormat5, 1, 2208, 790);
                    _writeText(s_gameText[13], s_infoTextFormat3, 1, 2208, 850);
                    _writeText(s_gameText[int(m_engine.replayAfterFoul ? 14 : 15)], s_infoTextFormat4, 1, 2208, 885);
                    _writeText(s_gameText[5], s_infoTextFormat3, 1, 2208, 950);
                    _writeText(s_gameText[4], s_infoTextFormat3, 1, 2208, 1030);
                }
                else if (gameState === GameState.CHOOSE_COLOUR) {
                    _writeText(s_gameText[6], s_infoTextFormat3, 1, 2208, 790);
                    _writeText(s_gameText[4], s_infoTextFormat3, 1, 2208, 890);
                }
                else if (gameState === GameState.CHOOSE_TIE_PLAYER) {
                    _writeText(s_gameText[22], s_infoTextFormat5, 1, 2208, 790);
                    _writeText(s_gameText[23], s_infoTextFormat3, 1, 2208, 850);
                    _writeText((m_engine.currentPlayer === 1) ? m_playerName2 : m_playerName1, s_infoTextFormat4, 1, 2208, 885);
                    _writeText(s_gameText[5], s_infoTextFormat3, 1, 2208, 950);
                    _writeText(s_gameText[4], s_infoTextFormat3, 1, 2208, 1030);
                }
                else if (gameState === GameState.GAME_OVER) {
                    var matchEnd: Boolean = m_engine.framesWonPlayer1 === m_engine.targetFrames || m_engine.framesWonPlayer2 === m_engine.targetFrames;
                    var winnerText: String = s_gameText[int(matchEnd ? 19 : 18)].replace("$1", (m_engine.scorePlayer1 > m_engine.scorePlayer2) ? m_playerName1 : m_playerName2);
                    _writeText(s_gameText[int(matchEnd ? 17 : 16)], s_infoTextFormat5, 1, 2208, 790);
                    _writeText(winnerText, s_infoTextFormat3, 1, 2208, 850);
                    _writeText(s_gameText[int(matchEnd ? 21 : 20)], s_infoTextFormat3, 1, 2208, 940);
                }
            }
        }
        
        /**
         * Enggages/disengages the match options menu.
         */
        private function _toggleMatchMenuEnabled(): void {
            var rect: Rectangle = m_rectObject;

            if (!m_matchMenuEnabled) {
                var tempGraphics: Graphics = m_tempShape.graphics;

                tempGraphics.clear();
                tempGraphics.beginFill(0x000000, 0.7);
                tempGraphics.drawRect(0, 0, m_gameAreaBitmapData.width, m_gameAreaBitmapData.height);
                m_gameAreaBitmapData.draw(m_tempShape);

                _drawMatchMenu();

                addChild(m_menuInputField_pName1);
                addChild(m_menuInputField_pName2);
                addChild(m_menuInputField_targetFrames);

                m_matchMenuEnabled = true;
            }
            else {
                rect.x = rect.y = 0;
                rect.width = m_gameAreaBitmapData.width;
                rect.height = m_gameAreaBitmapData.height;

                removeChild(m_menuInputField_pName1);
                removeChild(m_menuInputField_pName2);
                removeChild(m_menuInputField_targetFrames);

                m_gameAreaBitmapData.fillRect(rect, 0xFFFFFFFF);

                _drawTable();
                _drawInfoDisplay();

                m_matchMenuEnabled = false;
            }
        }
        
        /**
         * Handles a button lick in the match menu.
         * 
         * @param clickedButton The index of the clicked button in the _buttonRanges array.
         */
        private function _handleMatchMenuButtonClick(clickedButton: int): void {
            if (clickedButton === -1)
                return;

            if (clickedButton === BUTTON_SINGLE_PLAYER) {
                m_isSinglePlayerGame = true;
            }
            else if (clickedButton === BUTTON_TWO_PLAYER) {
                m_isSinglePlayerGame = false;
            }
            else if (clickedButton === BUTTON_FIRST_FRAME_P1) {
                m_engine.setFirstFrameOpenPlayer(0);
            }
            else if (clickedButton === BUTTON_FIRST_FRAME_P2) {
                m_engine.setFirstFrameOpenPlayer(1);
            }
            else if (clickedButton === BUTTON_START_MATCH) {
                m_playerName1 = m_menuInputField_pName1.text;
                if (m_playerName1.length === 0)
                    m_playerName1 = "Player 1";

                m_playerName2 = m_isSinglePlayerGame ? "CPU" : m_menuInputField_pName2.text;
                if (m_playerName2.length === 0)
                    m_playerName2 = "Player 2";

                m_engine.setTargetFrames(int(m_menuInputField_targetFrames.text));
                m_engine.setCurrentPlayer(m_engine.firstFrameOpenPlayer);

                _toggleMatchMenuEnabled();

                m_matchBegin = true;
            }
            
            if (m_matchMenuEnabled)
                m_matchMenuChanged = true;
        }
        
        /**
         * Draws the match options menu.
         */
        private function _drawMatchMenu(): void {
            var rect: Rectangle = m_rectObject;
            var pt: Point = m_pointObject;
            var buttonRanges: Vector.<Rectangle> = s_matchMenuButtonRanges;
            var rf: Number = m_resolutionFactor;
            
            // Draw the background.
            rect.x = rect.y = 0;
            rect.width = m_matchMenuBackBitmapData.width;
            rect.height = m_matchMenuBackBitmapData.height;
            pt.x = (m_gameAreaBitmapData.width - m_matchMenuBackBitmapData.width) * 0.5;
            pt.y = (m_gameAreaBitmapData.height - m_matchMenuBackBitmapData.height) * 0.5;
            m_gameAreaBitmapData.copyPixels(m_matchMenuBackBitmapData, rect, pt, null, null, true);
            
            // Draw the circles for selected options of the radio buttons
            var tempGraphics: Graphics = m_tempShape.graphics;
            tempGraphics.clear();
            tempGraphics.beginFill(0x333333, 1);
            
            var buttonRect: Rectangle;
            var buttonRadius: Number = 7.0 * rf;

            buttonRect = buttonRanges[m_isSinglePlayerGame ? BUTTON_SINGLE_PLAYER : BUTTON_TWO_PLAYER];
            tempGraphics.drawCircle(
                (buttonRect.x + buttonRect.width * 0.5) * rf, 
                (buttonRect.y + buttonRect.height * 0.5) * rf,
                buttonRadius
            );
            buttonRect = buttonRanges[(m_engine.firstFrameOpenPlayer === 1) ? BUTTON_FIRST_FRAME_P2 : BUTTON_FIRST_FRAME_P1];
            tempGraphics.drawCircle(
                (buttonRect.x + buttonRect.width * 0.5) * rf, 
                (buttonRect.y + buttonRect.height * 0.5) * rf,
                buttonRadius
            );
            
            m_gameAreaBitmapData.draw(m_tempShape);
            
            // Draw the static menu text.
            _writeText(s_gameText[24], s_menuTextFormat1, 1, 1210, 332);
            _writeText(s_gameText[25], s_menuTextFormat2, 0, 840, 444);
            _writeText(s_gameText[28], s_menuTextFormat2, 0, 840, 504);
            _writeText(s_gameText[29], s_menuTextFormat2, 0, 840, 566);
            _writeText(s_gameText[34], s_menuTextFormat2, 0, 840, 628);
            _writeText(s_gameText[30], s_menuTextFormat2, 0, 840, 690);
            _writeText(s_gameText[26], s_menuTextFormat3, 0, 1160, 444);
            _writeText(s_gameText[27], s_menuTextFormat3, 0, 1430, 444);
            _writeText(s_gameText[31], s_menuTextFormat3, 0, 1160, 690);
            _writeText(s_gameText[int(m_isSinglePlayerGame ? 33 : 32)], s_menuTextFormat3, 0, 1430, 690);
            _writeText(s_gameText[35], s_menuTextFormat4, 1, 1204, 786);
        }
        
        /**
         * Gets the index of a clicked menu button.
         * 
         * @param clickX The x coordinate of the mouse pointer location (in sprite coordinates)
         * @param clickY The y coordinate of the mouse pointer location (in sprite coordinates)
         * @return The index of the clicked button, or -1 if the click was not on a button.
         */
        private function _getClickedMenuButton(clickX: Number, clickY: Number): int {
            // Convert clickX and clickY to table coordinates before checking.
            var rfi: Number = 1 / m_resolutionFactor;
            clickX *= rfi;
            clickY *= rfi;
            
            var ranges: Vector.<Rectangle> = s_matchMenuButtonRanges;

            for (var i: int = 0, n: int = ranges.length; i < n; i++) {
                var buttonRect: Rectangle = ranges[i];
                if (clickX >= buttonRect.x
                    && clickY >= buttonRect.y
                    && clickX <= buttonRect.x + buttonRect.width
                    && clickY <= buttonRect.y + buttonRect.height)
                {
                    return i;
                }
            }

            return -1;
        }
        
        /**
         * Writes text onto the game area.
         * 
         * @param text The text to render.
         * @param format The TextFormat to use for drawing the text.
         * @param align The alignment of the text: 0 (left), 1 (centre), 2 (right)
         * @param x The x coordinate of the text's position (in resolution-independent coordinates).
         * @param y The y coordinate of the text's position (in resolution-independent coordinates).
         */
        private function _writeText(text: String, format: TextFormat, align: int, x: Number, y: Number): void {
            var matrix: Matrix = m_transformMatrix;
            var textField: TextField;
            var oldAlign: String = format.align;
            
            if (align === 0) {
                textField = m_tempTextField1;
                format.align = TextFormatAlign.LEFT;
            }
            else if (align === 1) {
                textField = m_tempTextField2;
                format.align = TextFormatAlign.CENTER;
            }
            else if (align === 2) {
                textField = m_tempTextField3;
                format.align = TextFormatAlign.RIGHT;
            }
                
            textField.defaultTextFormat = format;
            textField.text = text;
            matrix.a = matrix.d = m_resolutionFactor;
            matrix.b = matrix.c = 0;
            matrix.tx = x * m_resolutionFactor;
            matrix.ty = y * m_resolutionFactor;
            m_gameAreaBitmapData.draw(textField, matrix);

            format.align = oldAlign;
        }
        
    }

}