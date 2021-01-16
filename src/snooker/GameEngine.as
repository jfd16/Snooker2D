package snooker {
    
    import flash.utils.getTimer;
    
    /*
     * The dimensions used in the game engine are:
     * Table width (cushion-to-cushion): 1713.1
     * Table height (cushion-to-cushion): 853.4
     * Ball radius: 12.6
     * Pocket radius: 22.5
     * Baulk-line position: 353.8 (from left)
     * D-radius: 140.2
     * 
     * These are hardcoded into the engine code for performance reasons as the ActionScript
     * compiler does not substitute expressions involving 'const' variables.
     * 
     * The coordinate system used by code in the game engine has the origin at the upper left corner
     * of the table's playable area (i.e. without the cushions)
     */
    
    public final class GameEngine {
        
        /**
         * Set this to true to enable debug tracing of the table state on every shot.
         */
        public static var enableShotDebugTracing: Boolean = false;
        
        /**
         * The positions of the balls at the start of the game.
         */
        internal static const initialBallPositions: Vector.<Number> = new <Number>[
            255.0, 490.0,     // Cue ball
            353.8, 566.9,     // Yellow
            353.8, 286.5,     // Green
            353.8, 426.7,     // Brown
            856.6, 426.7,     // Blue
            1284.8, 426.7,    // Pink
            1557.6, 426.7,    // Black
            
            // Reds...
            1311.3, 426.7,    1333.2, 414.1,    1333.2, 439.3,    1355.1, 401.5,    1355.1, 426.7,
            1355.1, 451.9,    1377.0, 388.9,    1377.0, 414.1,    1377.0, 439.3,    1377.0, 464.5, 
            1398.9, 376.3,    1398.9, 401.5,    1398.9, 426.7,    1398.9, 451.9,    1398.9, 477.1,
        ];
        
        /**
         * The cushion data.
         */
        public static const cushions: Vector.<Cushion> = new <Cushion>[
            // Left
            new Cushion(
                new <Number>[-22.7, 849.6,   0.0, 801.6,    0.0, 51.8,   -22.7, 3.8],
                new <Number>[0.90401, 0.42752,   1.00000, 0.00000,   0.90401, -0.42752,  -1.00000, 0.00000]
            ),
            // Top left
            new Cushion(
                new <Number>[3.8, -22.7,   51.8, 0.0,   799.4, 0.0,   837.6, -22.7],
                new <Number>[-0.42752, 0.90401,   0.00000, 1.00000,   0.51085, 0.85967,   0.00000, -1.00000]
            ),
            // Top right
            new Cushion(
                new <Number>[875.5, -22.7,   913.7, 0.0,   1661.3, 0.0,   1709.3, -22.7],
                new <Number>[-0.51085, 0.85967,   0.00000, 1.00000,   0.42752, 0.90401,   0.00000, -1.00000]
            ),
            // Right
            new Cushion(
                new <Number>[1735.8, 3.8,    1713.1, 51.8,   1713.1, 801.6,  1735.8,  849.6],
                new <Number>[-0.90401, -0.42752,  -1.00000, 0.00000,  -0.90401, 0.42752,   1.00000, 0.00000]
            ),
            // Bottom right
            new Cushion(
                new <Number>[1709.3, 876.1,   1661.3, 853.4,   913.7, 853.4,   875.5, 876.1],
                new <Number>[0.42752, -0.90401,   0.00000, -1.00000,  -0.51085, -0.85967,  0.00000, 1.00000]
            ),
            // Bottom left
            new Cushion(
                new <Number>[837.6, 876.1,    799.4, 853.4,   51.8, 853.4,    3.8, 876.1],
                new <Number>[0.51085, -0.85967,   0.00000, -1.00000,  -0.42752, -0.90401,  0.00000, 1.00000]
            ),
        ];
        
        /**
         * The positions of the pocket centres on the table.
         */
        internal static var pocketCentres: Vector.<Number> = new <Number>[
          // Top left     Top centre     Top right        Bottom right      Bottom centre    Bottom left
          -5.8, -5.8,     856.6, -5.8,   1718.9, -5.8,    1718.9, 859.2,    856.6, 859.2,    -5.8, 859.2,
        ];

        private var m_gameState: int = GameState.CUEBALL_IN_HAND;
        
        /**
         * The state of the game. Refer the the GameState class for possible values.
         */
        public function get gameState(): int {
            return m_gameState;
        }

        internal function setGameState(state: int): void {
            m_gameState = state;
        }
        
        private var m_scorePlayer1: int = 0;
        private var m_scorePlayer2: int = 0;
        
        /**
         * The score of the first player.
         */
        public function get scorePlayer1(): int {
            return m_scorePlayer1;
        }
        
        /**
         * The score of the second player.
         */
        public function get scorePlayer2(): int {
            return m_scorePlayer2;
        }

        private var m_framesWonPlayer1: int = 0;
        private var m_framesWonPlayer2: int = 0;

        /**
         * The number of frames won by the first player.
         */
        public function get framesWonPlayer1(): int {
            return m_framesWonPlayer1;
        }

        /**
         * The number of frames won by the first player.
         */
        public function get framesWonPlayer2(): int {
            return m_framesWonPlayer2;
        }

        private var m_targetFrames: int = 1;

        /**
         * The number of frames required to win the match.
         */
        public function get targetFrames(): int {
            return m_targetFrames;
        }

        internal function setTargetFrames(value: int): void {
            m_targetFrames = (value === 0) ? 1 : value;
        }
        
        private var m_currentBreak: int = 0;

        /**
         * The points scored in the current break.
         */
        public function get currentBreak(): int {
            return m_currentBreak;
        }

        private var m_bestBreak: int = 0;
        
        /**
         * The points scored in the best break in the game.
         */
        public function get bestBreak(): int {
            return m_bestBreak;
        }

        private var m_currentPlayer: int = 0;
        
        /**
         * The current player (0=player1, 1=player2)
         */
        public function get currentPlayer(): int {
            return m_currentPlayer;
        }

        internal function setCurrentPlayer(value: int): void {
            m_currentPlayer = value;
        }
        
        private var m_firstFrameOpenPlayer: int = 0;

        /**
         * The player opening the first frame (0=player1, 1=player2)
         */
        public function get firstFrameOpenPlayer(): int {
            return m_firstFrameOpenPlayer;
        }

        internal function setFirstFrameOpenPlayer(player: int): void {
            m_firstFrameOpenPlayer = player;
        }
        
        private var m_currentColour: int = 1;
        
        /**
         * The colour of the target ball that must be hit by the cue ball in the current shot.
         */
        public function get currentColour(): int {
            return m_currentColour;
        }

        internal function setCurrentColour(colour: int): void {
            m_currentColour = colour;
        }
        
        /**
         * An array containing the Ball objects representing the balls in the game (both those on the table
         * as well as potted). Balls on the table are always positioned before potted balls.
         * The cue ball is always the first element (index 0) in this array, except possibly when a shot
         * is in progress.
         */
        public const balls: Vector.<Ball> = new Vector.<Ball>(22, true);
        
        private var m_ballsOnTableCount: int;

        /**
         * The number of balls currently on the table.
         */
        public function get ballsOnTableCount(): int {
            return m_ballsOnTableCount;
        }
        
        /**
         * A set of bit flags indicating the state of the arrow keys (bit is set to 1 if the key is down,
         * 0 if it is up)
         * 1: Left arrow
         * 2: Up arrow
         * 4: Right arrow
         * 8: Down arrow
         */
        private var m_arrowKeyState: int = 0;
        
        /**
         * A set of bit flags indicating whether the following keys have been pressed in the current frame:
         * (Bit is set to 1 is the key is pressed, cleared at the end of the frame)
         * 1: Left arrow
         * 2: Right arrow
         * 4: Enter key
         * 8: Backspace key
         */
        private var m_keyFlags: int = 0;
        
        /**
         * A value representing the current time, relative to some reference value, in milliseconds.
         */
        private var m_timeStamp: Number;
        
        /**
         * A value representing the time at which an arrow key was last pressed or released, in millizeconds,
         * relative to the same reference value used for _timeStamp.
         */
        private var m_lastArrowKeyTimeStamp: Number;
        
        /**
         * A value representing the time at which the current shot ended with all balls stopped, in millizeconds,
         * relative to the same reference value used for m_timeStamp.
         * Applicable in states: SHOT_IN_PROGRESS(5), AFTER_SHOT_DELAY(10)
         */
        private var m_shotEndTimeStamp: Number;
        
        /**
         * A value representing the time between the previous frame and the current frame, in millizeconds.
         */
        private var m_elapsedTime: Number;
        
        /**
         * The point value of the colour of the ball last hit by the cue ball, or -1 is no ball is hit.
         * Applicable in states: SHOT_IN_PROGRESS(5)
         */
        private var m_lastHitBallColour: int;
        
        /**
         * The number of balls of the current colour which have been potted in the current shot.
         * Applicable in states: SHOT_IN_PROGRESS(5)
         */
        private var m_currentColourBallsPotted: int;
        
        /**
         * The total number of red balls which have been potted.
         */
        private var m_totalRedsPotted: int;
        
        /**
         * The number of foul points (which are to be given to the opponent) which have been scored so far
         * in the current shot.
         * Applicable in states: SHOT_IN_PROGRESS(5)
         */
        private var m_foulPointsScored: int;

        private var m_mouseX: Number = 0;
        private var m_mouseY: Number = 0;
        
        /**
         * The x coordinate of the mouse pointer's position in the current frame.
         */
        public function get mouseX(): Number {
            return m_mouseX;
        }
        
        /**
         * The y coordinate of the mouse pointer's position in the current frame.
         */
        public function get mouseY(): Number {
            return m_mouseY;
        }

        internal function setMousePosition(x: Number, y: Number): void {
            m_mouseX = x;
            m_mouseY = y;
        }

        /**
         * The x coordinate of the mouse pointer's position in the previous frame.
         */
        private var m_lastMouseX: Number = 0;
        
        /**
         * The y coordinate of the mouse pointer's position in the previous frame.
         */
        private var m_lastMouseY: Number = 0;
        
        /**
         * This is set to true if the current shot is for a colour ball after succesfully potting a red ball.
         */
        private var m_shootingColourAfterRed: Boolean;
        
        private var m_ballInHandAfterFoul: Boolean;

        /**
         * This is set to true if the cue ball was potted in a foul, which would result in a ball-in-hand
         * in the next shot.
         * Applicable in states: CHOOSE_FOUL_PLAYER(6)
         */
        public function get ballInHandAfterFoul(): Boolean {
            return m_ballInHandAfterFoul;
        }

        internal function setBallInHandAfterFoul(value: Boolean): void {
            m_ballInHandAfterFoul = value;
        }
        
        private var m_replayAfterFoul: Boolean;

        /**
         * This is set to true if a player committed a foul and the opponent requests the fouling player to
         * replay.
         * Applicable in states: CHOOSE_FOUL_PLAYER(6)
         */
        public function get replayAfterFoul(): Boolean {
            return m_replayAfterFoul;
        }
        
        /**
         * The computed relative collision time (RCT) of the first collision in the frame or subframe.
         * RCT is a value between 0 and 1 indicating the time at which impact is predicted to occur
         * as a fraction of the remaining frame/subframe time.
         * Applicable in states: SHOT_IN_PROGRESS(5)
         */
        private var m_minRCT: Number;
        
        private var m_cueTipDistance: Number = 0;
        private var m_cueDirX: Number;
        private var m_cueDirY: Number;

        /**
         * The distance of the cue tip from the centre of the cue ball.
         * Applicable in states: CUE_SHOT_POWER(3)
         */
        public function get cueTipDistance(): Number {
            return m_cueTipDistance;
        }
        
        /**
         * The x component of the unit vector of the direction in which the cue ball will be hit.
         * Applicable in states: CUE_AIM(2), CUE_SHOT_POWER(3), CUE_SHOOT(4)
         */
        public function get cueDirX(): Number {
            return m_cueDirX;
        }
        
        /**
         * The y component of the unit vector of the direction in which the cue ball will be hit.
         * Applicable in states: CUE_AIM(2), CUE_SHOT_POWER(3), CUE_SHOOT(4)
         */
        public function get cueDirY(): Number {
            return m_cueDirY;
        }

        internal function setCueDir(x: Number, y: Number): void {
            m_cueDirX = x;
            m_cueDirY = y;
        }

        private var m_predictedTargetBall: Ball;
        private var m_predictedTargetDirX: Number;
        private var m_predictedTargetDirY: Number;
        private var m_predictedTargetImpactX: Number;
        private var m_predictedTargetImpactY: Number;

        /**
         * The target ball that is predicted to be hit by the cue ball first, given the direction
         * in which the cue ball is hit. Null if no ball is predicted to be hit.
         * Applicable in states: CUE_AIM(2), CUE_SHOT_POWER(3)
         */
        public function get predictedTargetBall(): Ball {
            return m_predictedTargetBall;
        }
        
        /**
         * The x component of the unit vector of the predicted direction of the target ball after being
         * hit by the cue ball. Only applicable is predictedTargetBall is not null.
         * Applicable in states: CUE_AIM(2), CUE_SHOT_POWER(3)
         */
        public function get predictedTargetDirX(): Number {
            return m_predictedTargetDirX;
        }
        
        /**
         * The x component of the unit vector of the predicted direction of the target ball after being
         * hit by the cue ball. Only applicable is predictedTargetBall is not null.
         * Applicable in states: CUE_AIM(2), CUE_SHOT_POWER(3)
         */
        public function get predictedTargetDirY(): Number {
            return m_predictedTargetDirY;
        }

        /**
         * The x coordinate of the centre of the cue ball at the point of impact with the predicted target
         * ball. Only applicable is predictedTargetBall is not null.
         * Applicable in states: CUE_AIM(2), CUE_SHOT_POWER(3)
         */
        public function get predictedTargetImpactX(): Number {
            return m_predictedTargetImpactX;
        }

        /**
         * The y coordinate of the centre of the cue ball at the point of impact with the predicted target
         * ball. Only applicable is predictedTargetBall is not null.
         * Applicable in states: CUE_AIM(2), CUE_SHOT_POWER(3)
         */
        public function get predictedTargetImpactY(): Number {
            return m_predictedTargetImpactY;
        }

        /**
         * The speed of the cue tip.
         * Applicable in states: CUE_SHOT_POWER(3), CUE_SHOOT(4)
         */
        private var m_cueTipSpeed: Number;
        
        public function GameEngine() {
            _initBalls();
            m_timeStamp = getTimer();
        }
        
        /**
         * Sets all the balls to their initial positions on the table.
         */
        private function _initBalls(): void {
            var i: int;
            var initPositions: Vector.<Number> = initialBallPositions;

            for (i = 0; i < 22; i++) {
                var ball: Ball = balls[i];
                if (ball === null) {
                    ball = new Ball();
                    balls[i] = ball;
                }
                
                ball.potStatus = 0;
                if (i === 0)
                    ball.colour = 0;
                else if (i <= 6)
                    ball.colour = i + 1;
                else
                    ball.colour = 1;
                
                ball.x = initPositions[int(i << 1)];
                ball.y = initPositions[int((i << 1) + 1)];
                ball.vx = 0;
                ball.vy = 0;
            }
            
            m_ballsOnTableCount = 22;
            m_totalRedsPotted = 0;
            spotCueBallInD();
        }
        
        /**
         * Handles keyboard input.
         * 
         * @param keyCode The keycode of the key pressed
         * @param keyState The state of the pressed key (1 for down, 0 for up)
         */
        public function keyPress(keyCode: int, keyState: int): void {
            if (keyCode >= 37 && keyCode <= 40) {
                // Handle arrow keys
                var oldArrowKeyState: int = m_arrowKeyState;
                m_arrowKeyState = (m_arrowKeyState & ~(1 << (keyCode - 37))) | (keyState << (keyCode - 37));

                if (m_arrowKeyState !== oldArrowKeyState)
                    m_lastArrowKeyTimeStamp = getTimer()
            }
            
            if (keyState) {
                if (keyCode === 37)   // Left arrow
                    m_keyFlags |= 1;
                else if (keyCode === 39)  // Right arrow
                    m_keyFlags |= 2;
                else if (keyCode === 13 || keyCode === 108)  // Enter
                    m_keyFlags |= 4;
                else if (keyCode === 8)   // Backspace
                    m_keyFlags |= 8;
            }
        }
        
        /**
         * Sets the cue tip position for the required shot speed.
         * 
         * @param speed The speed of the cue ball when struck.
         * NOTE: This is the strike speed of the cue ball, which may not be the same as that of the cue tip.
         */
        internal function setCueBallSpeed(speed: Number): void {
            m_cueTipDistance = Math.sqrt(speed * 1.05263157894737 - 0.242) * 92.4500327042049 + 6.5;
        }
        
        /**
         * Update function called on every frame. This calls a state-specific update function.
         */
        public function update(): void {
            m_elapsedTime = getTimer() - m_timeStamp;
            m_timeStamp += m_elapsedTime;
            
            // Call the state-specific update function
            switch (m_gameState) {
                case GameState.CUEBALL_IN_HAND:
                    _updateState_cueballInHand();
                    break;
                case GameState.CUE_AIM:
                    _updateState_cueAim();
                    break;
                case GameState.CUE_SHOT_POWER:
                    _updateState_cueShotPower();
                    break;
                case GameState.CUE_SHOOT:
                    _updateState_cueShoot();
                    break;
                case GameState.SHOT_IN_PROGRESS:
                    _updateState_shotInProgress();
                    break;
                case GameState.CHOOSE_FOUL_PLAYER:
                    _updateState_chooseFoulPlayer();
                    break;
                case GameState.CHOOSE_COLOUR:
                    _updateState_chooseColour();
                    break;
                case GameState.CHOOSE_TIE_PLAYER:
                    _updateState_chooseTiePlayer();
                    break;
                case GameState.GAME_OVER:
                    _updateState_gameOver();
                    break;
                case GameState.AFTER_SHOT_DELAY:
                    _updateState_afterShotDelay();
                    break;
            }
            
            m_lastMouseX = m_mouseX;
            m_lastMouseY = m_mouseY;
            m_keyFlags = 0;
        }
        
        private function _updateState_cueballInHand(): void {
            if (m_keyFlags & 4) {
                // Switch to next state if Enter key is pressed.
                _setDefaultCuePosition();
                m_gameState = GameState.CUE_AIM;
                return;
            }

            var arrowKeys: int = m_arrowKeyState;
            if (!arrowKeys)
                return;
            
            var cueBall: Ball = balls[0];

            // Calculate the new position of the cue ball based on the keyboard input.
            var ballSpeed: Number = 0.02 + 0.0003 * (m_timeStamp - m_lastArrowKeyTimeStamp);
            if (ballSpeed > 0.2)
                ballSpeed = 0.2;

            var newX: Number = cueBall.x + ballSpeed * m_elapsedTime * (((arrowKeys & 4) >> 2) - (arrowKeys & 1));
            var newY: Number = cueBall.y + ballSpeed * m_elapsedTime * (((arrowKeys & 8) >> 3) - ((arrowKeys & 2) >> 1));
            
            // If the ball is going outside the baulk line, position it on the line.
            if (newX > 353.8)
                newX = 353.8;

            // Check if the ball is going outside the 'D'
            var dd: Number = (newX - 353.8) * (newX - 353.8) + (newY - 426.7) * (newY - 426.7);
            var ratio: Number;
            if (dd > 19656.04) {
                // Position the ball on the 'D', at the intersection point of the line joining the
                // centre of the D with the new ball's position with the D itself.
                ratio = Math.sqrt(19656.04 / dd);
                newX = 353.8 + (newX - 353.8) * ratio;
                newY = 426.7 + (newY - 426.7) * ratio;
            }
            
            // Finally, check for collisions with other balls. If there is contact with any ball, don't move the
            // cue ball at all. However, a key press is mimicked (by setting the _lastArrowKeyTimeStamp
            // property) so that the ball's speed resets to the minimum and it gets as close as possible
            // to the colliding ball.
            if (_checkCollisionForSpotting(cueBall, newX, newY, true)) {
                m_lastArrowKeyTimeStamp = m_timeStamp;
                return;
            }
            
            cueBall.x = newX;
            cueBall.y = newY;
        }
        
        private function _updateState_cueAim(): void {
            if (m_keyFlags & 4) {
                // Switch to next state if Enter key is pressed
                m_gameState = GameState.CUE_SHOT_POWER;
                return;
            }
            
            var cueDirChanged: Boolean = false;

            if (m_arrowKeyState) {
                // Use left and right arrow keys to control cue angle.
                var cueAngleSpeed: Number = 0.00001 + 0.0000004 * (m_timeStamp - m_lastArrowKeyTimeStamp);
                if (cueAngleSpeed > 0.002)
                    cueAngleSpeed = 0.002;

                var rotateAngle: Number = cueAngleSpeed * m_elapsedTime * (((m_arrowKeyState & 4) >> 2) - (m_arrowKeyState & 1));
                var rotateCos: Number = Math.cos(rotateAngle);
                var rotateSin: Number = Math.sin(rotateAngle);

                var oldX: Number = m_cueDirX;
                m_cueDirX = oldX * rotateCos - m_cueDirY * rotateSin;
                m_cueDirY = oldX * rotateSin + m_cueDirY * rotateCos;

                cueDirChanged = true;
            }

            if (m_mouseX !== m_lastMouseX || m_mouseY !== m_lastMouseY) {
                // Aim the cue at where the mouse is pointing.
                var newDirX: Number = m_mouseX - balls[0].x;
                var newDirY: Number = m_mouseY - balls[0].y;

                var norm: Number = 1 / Math.sqrt(newDirX * newDirX + newDirY * newDirY);
                m_cueDirX = newDirX * norm;
                m_cueDirY = newDirY * norm;

                cueDirChanged = true;
            }
            
            if (cueDirChanged)
                _predictTargetBall();
        }
        
        private function _updateState_cueShotPower(): void {
            if (m_keyFlags & 4) {   // Enter key
                m_cueTipSpeed = (m_cueTipDistance - 6.5) * (m_cueTipDistance - 6.5) * 0.000117 + 0.242;
                m_gameState = GameState.CUE_SHOOT;
                return;
            }
            if (m_keyFlags & 8) {   // Backspace key
                m_gameState = 2;
                return;
            }
            
            if (m_arrowKeyState) {
                // Use up and down arrow keys to control shot power.
                var speed: Number = 0.006 + 0.0003 * (m_timeStamp - m_lastArrowKeyTimeStamp);
                if (speed > 0.2)
                    speed = 0.2;
                m_cueTipDistance += speed * m_elapsedTime * (((m_arrowKeyState & 8) >> 3) - ((m_arrowKeyState & 2) >> 1));
            }

            if (m_mouseY !== m_lastMouseY)
                m_cueTipDistance += (m_mouseY - m_lastMouseY) * 0.25;
            
            if (m_cueTipDistance > 120)
                m_cueTipDistance = 120;
            else if (m_cueTipDistance < 20)
                m_cueTipDistance = 20;
        }
        
        private function _updateState_cueShoot(): void {
            m_cueTipDistance -= m_cueTipSpeed * m_elapsedTime;

            if (m_cueTipDistance < 12.6) {
                // Shoot the cue ball!
                var cueBall: Ball = balls[0];
                cueBall.vx = m_cueTipSpeed * 0.95 * m_cueDirX;
                cueBall.vy = m_cueTipSpeed * 0.95 * m_cueDirY;
                
                if (enableShotDebugTracing)
                    _logTableState();
                
                m_lastHitBallColour = -1;
                m_currentColourBallsPotted = 0;
                m_foulPointsScored = 0;
                m_gameState = GameState.SHOT_IN_PROGRESS;
            }
        }
        
        private function _updateState_shotInProgress(): void {
            var vMaxSquared: Number = 0;
            var balls: Vector.<Ball> = this.balls;
            var ball: Ball;
            var ballCount: int = m_ballsOnTableCount;
            var i: int, j: int;
            
            // To minimize the effects of linear interpolation approximation during collisions, the
            // frame is divided into multiple 'subframes', with each subframe being processed in order
            // (but only the last one rendered). The number of subframes required depends on the speed of
            // the fastest ball, as linear interpolation errors become more significant at higher speeds
            // for the same frame rate.

            for (i = 0; i < ballCount; i++) {
                ball = balls[i];
                var vb: Number = ball.vx * ball.vx + ball.vy * ball.vy;
                if (vMaxSquared < vb)
                    vMaxSquared = vb;
            }
            
            if (vMaxSquared === 0) {
                // All balls are at rest, so end the shot.
                // (The engine automatically sets balls' velocities to zero when they are very small,
                // so vmax can be compared directly with zero without using an epsilon)
                m_shotEndTimeStamp = m_timeStamp;
                m_gameState = GameState.AFTER_SHOT_DELAY;
                return;
            }
            
            var subFrames: int = int(Math.sqrt(vMaxSquared) * 2) + 1;
            var subFrameTime: Number = 0;
            m_timeStamp -= m_elapsedTime;
            var subFrameDuration: Number = m_elapsedTime / subFrames;
            
            while (subFrames) {
                m_timeStamp += subFrameDuration;
                subFrameTime = 0;
                
                // Begin sub frame
                while (true) {
                    // Calculate the expected new state of each ball (assuming no collisions)
                    // This expected state is stored in the x2, y2, vx2, vy2 fields of the Ball object.
                    for (i = 0; i < ballCount; i++) {
                        ball = balls[i];
                        if (ball.vx !== 0 || ball.vy !== 0) {
                            _calculateExpectedBallState(ball, subFrameDuration * (1 - subFrameTime));
                        }
                        else {
                            ball.x2 = ball.x;
                            ball.y2 = ball.y;
                            ball.vx2 = ball.vy2 = 0;
                        }
                    }
                    
                    var collideBall1: Ball = null;
                    var collideBall2: Ball = null;
                    m_minRCT = 1;
                    
                    // First check for 'collisions' with the pockets (i.e. if balls have been potted)
                    for (i = 0; i < ballCount; i++) {
                        if (_checkBallPocketEntry(balls[i]))
                            collideBall1 = balls[i];
                    }
                    // Then check for collisions with the cushions.
                    for (i = 0; i < ballCount; i++) {
                        if (_checkBallCushionCollisions(balls[i]))
                            collideBall1 = balls[i];
                    }
                    // Finally, check for collisions between balls.
                    for (i = 1; i < ballCount; i++) {
                        for (j = 0; j < i; j++) {
                            if (_checkTwoBallCollision(balls[i], balls[j])) {
                                collideBall1 = balls[i];
                                collideBall2 = balls[j];
                            }
                        }
                    }
                    
                    if (!collideBall1 && !collideBall2) {
                        // No collision, set the new ball states and end the sub frame.
                        for (i = 0; i < ballCount; i++) {
                            ball = balls[i];
                            ball.x = ball.x2;
                            ball.y = ball.y2;
                            ball.vx = ball.vx2;
                            ball.vy = ball.vy2;
                        }
                        break;
                    }
                    
                    // It is now known which collision has happened first. The _minRCT field has the relative
                    // collision time for the first collision while collideBall1 and collideBall2 are the
                    // ball(s) involved.
                    
                    var minRCT: Number = m_minRCT;
                    for (i = 0; i < ballCount; i++) {
                        ball = balls[i];
                        if (ball === collideBall1 && ball.potStatus !== 0) {
                            // Ball has been potted, move it to the end of the balls array.
                            ball.potStatus = 2;
                            ballCount--;
                            m_ballsOnTableCount = ballCount;
                            balls[i] = balls[ballCount];
                            balls[ballCount] = ball;
                            i--;
                            
                            if (ball.colour === m_currentColour) {
                                m_currentColourBallsPotted++;
                            }
                            else {
                                // If the ball potted is not of the active colour (or is the cue ball),
                                // it is a foul.
                                var foulValue: int = ball.colour ? ball.colour : 4;
                                if (m_foulPointsScored < foulValue)
                                    m_foulPointsScored = foulValue;
                            }

                            if (ball.colour === 1)
                                m_totalRedsPotted++;
                                
                            ball.vx = ball.vy = 0;  // Set velocity of potted ball to zero
                        }
                        else {
                            // Calculate the intermediate state of the ball. The position is found by
                            // linear interpolation. If the ball is involved in the collision, its velocity
                            // is set to the computed post-collision value, otherwise it is linearly interpolated.
                            ball.potStatus = 0;
                            ball.x += minRCT * (ball.x2 - ball.x);
                            ball.y += minRCT * (ball.y2 - ball.y);
                            
                            if (ball === collideBall1 || ball === collideBall2) {
                                ball.vx = ball.vxc;
                                ball.vy = ball.vyc;

                                if ((collideBall1.colour === 0 || (collideBall2 !== null && collideBall2.colour === 0))
                                    && ball.colour !== 0)
                                {
                                    // If the ball is an object ball which collided with the cue ball, check for fouls
                                    // (in particular, a ball not of the active colour being hit first)
                                    if (m_lastHitBallColour === -1 && ball.colour !== m_currentColour && m_foulPointsScored < ball.colour)
                                        m_foulPointsScored = ball.colour;

                                    m_lastHitBallColour = ball.colour;
                                }
                            }
                            else {
                                ball.vx += minRCT * (ball.vx2 - ball.vx);
                                ball.vy += minRCT * (ball.vy2 - ball.vy);
                            }
                        }
                    }
                    
                    // Advance the subframe time and check for further collisions.
                    subFrameTime += minRCT * (1 - subFrameTime);
                    
                }
                // End sub frame
                subFrames--;
            }
            
        }
        
        private function _updateState_chooseFoulPlayer(): void {
            if (m_keyFlags & 3) {  // Left/right arrow
                m_replayAfterFoul = !m_replayAfterFoul;
                m_currentPlayer = 1 - m_currentPlayer;
            }
            
            else if (m_keyFlags & 4) { // Enter
                if (m_ballInHandAfterFoul) {
                    m_ballInHandAfterFoul = false;
                    m_gameState = GameState.CUEBALL_IN_HAND;
                }
                else {
                    _setDefaultCuePosition();
                    m_gameState = GameState.CUE_AIM;
                }
            }
        }
        
        private function _updateState_chooseColour(): void {
            if (m_keyFlags & 4) {  // Enter
                _setDefaultCuePosition();
                m_gameState = GameState.CUE_AIM;
            }
            else {
                m_currentColour += ((m_keyFlags & 2) >> 1) - (m_keyFlags & 1);
                if (m_currentColour === 8)
                    m_currentColour = 2;
                else if (m_currentColour === 1)
                    m_currentColour = 7;
            }
        }
        
        private function _updateState_chooseTiePlayer(): void {
            if (m_keyFlags & 4) { // Enter
                m_ballInHandAfterFoul = false;
                m_gameState = 1;
            } 
            else if (m_keyFlags & 3) {  // Left/right arrow
                m_currentPlayer = 1 - m_currentPlayer;
            }
        }
        
        private function _updateState_gameOver(): void {
            if (m_keyFlags & 4) {
                // Enter - start new game
                m_scorePlayer1 = 0;
                m_scorePlayer2 = 0;

                if (m_framesWonPlayer1 === m_targetFrames || m_framesWonPlayer2 === m_targetFrames) {
                    m_framesWonPlayer1 = 0;
                    m_framesWonPlayer2 = 0;
                    m_bestBreak = 0;
                    m_currentPlayer = m_firstFrameOpenPlayer;
                }
                else {
                    m_currentPlayer = (((m_framesWonPlayer1 + m_framesWonPlayer2) & 1) !== 0)
                        ? 1 - m_firstFrameOpenPlayer
                        : m_firstFrameOpenPlayer;
                }

                m_currentBreak = 0;
                m_currentColour = 1;
                m_ballInHandAfterFoul = false;

                _initBalls();
                m_gameState = GameState.CUEBALL_IN_HAND;
            }
        }
        
        private function _updateState_afterShotDelay(): void {
            if (m_timeStamp - m_shotEndTimeStamp >= 2000)  // 2 sec delay after shot
                _endShot();
        }
        
        /**
         * This function is called at the end of a shot, when all balls have stopped. It determines
         * the next state of the game.
         */
        private function _endShot(): void {
            // Calculate the players' scores after the shot.
            var pointsAwarded: int;
            var foulPointsScored: int = this.m_foulPointsScored;
            var currentColourPottedCount: int = this.m_currentColourBallsPotted;
            
            if (m_lastHitBallColour === -1)
                foulPointsScored = 4;  // If no ball is hit, a 4-point foul is awarded.
            
            if (foulPointsScored !== 0) {
                // Minimum number of points that must be awarded to the opponent in case of
                // a foul is 4 points or the value of the current colour, whichever is higher.
                pointsAwarded = foulPointsScored;
                if (pointsAwarded < m_currentColour)
                    pointsAwarded = m_currentColour;
                if (pointsAwarded < 4)
                    pointsAwarded = 4;
            }
            else {
                pointsAwarded = m_currentColour * currentColourPottedCount;
            }

            if (m_currentPlayer === ((foulPointsScored !== 0) ? 1 : 0))
                m_scorePlayer1 += pointsAwarded;
            else
                m_scorePlayer2 += pointsAwarded;
            
            // Keep track of the current break
            if (foulPointsScored === 0 && currentColourPottedCount !== 0) {
                m_currentBreak += pointsAwarded;
                if (m_bestBreak < m_currentBreak)
                    m_bestBreak = m_currentBreak;
            }
            else {
                m_currentBreak = 0;
            }

            var balls: Vector.<Ball> = this.balls;
            var ballsOnTableCount: Number = ballsOnTableCount;
            var i: int, j: int;
            var tempBall: Ball;
            
            if (m_currentColour === 7
                && m_totalRedsPotted === 15
                && !m_shootingColourAfterRed
                && (currentColourPottedCount !== 0 || foulPointsScored !== 0))
            {
                // If black is the only ball remaining and it is potted (or a foul committed)...
                if (m_scorePlayer1 !== m_scorePlayer2) {
                    // End of game
                    m_gameState = GameState.GAME_OVER;

                    if (m_scorePlayer1 > m_scorePlayer2)
                        m_framesWonPlayer1++;
                    else
                        m_framesWonPlayer2++;
                }
                else {
                    // Respot the cue ball and the black and enter a tiebreaker.
                    if (balls[0].colour) {
                        tempBall = balls[0];
                        balls[0] = balls[1];
                        balls[1] = tempBall;
                    }

                    spotCueBallInD();
                    _spotColourBall(balls[1]);

                    ballsOnTableCount = 2;
                    m_gameState = GameState.CHOOSE_TIE_PLAYER;
                }

                return;
            }
            
            // Determine the number of balls which are either on the table or have been
            // potted in the current shot.
            var ballsOnTableAndPottedCount: Number = ballsOnTableCount;
            for (i = ballsOnTableCount; i < 22; i++)
                ballsOnTableAndPottedCount += int(balls[i].potStatus === 2);
            
            if (ballsOnTableCount < ballsOnTableAndPottedCount && (foulPointsScored !== 0 || m_shootingColourAfterRed)) {
                // Respot balls if needed.
                // For respotting, sort the balls which have been potted in the current shot,
                // in descending order of point value with the cue ball having the highest value.
                
                for (i = ballsOnTableAndPottedCount - 1; i > ballsOnTableCount; i--) {
                    var swapped: Boolean = false;
                    for (j = ballsOnTableCount; j < i; j++) {
                        var ballValue1: int = balls[j].colour;
                        var ballValue2: int = balls[int(j + 1)].colour;
                        if (ballValue1 && (!ballValue2 || ballValue1 < ballValue2)) {
                            tempBall = balls[int(j + 1)];
                            balls[int(j + 1)] = balls[j];
                            balls[j] = tempBall;
                            swapped = true;
                        }
                    }
                    if (!swapped)
                        break;
                }
                
                // If the cue ball has been potted, ensure that it is the first element in the balls
                // array and then respot it.
                if (!balls[ballsOnTableCount].colour) {
                    tempBall = balls[0];
                    balls[0] = balls[ballsOnTableCount];
                    balls[ballsOnTableCount] = tempBall;
                    ballsOnTableCount++;
                    spotCueBallInD();
                    m_ballInHandAfterFoul = true;
                }
                
                // Now respot the colours in descending order of points.
                // Stop when a red ball is found.
                for (i = ballsOnTableCount; i < ballsOnTableAndPottedCount; i++) {
                    if (balls[i].colour === 1)
                        break;    
                    _spotColourBall(balls[i]);
                }

                ballsOnTableCount = i;
                this.m_ballsOnTableCount = ballsOnTableCount;
            }
            
            // After respotting, set the potStatus of all potted balls to 3 to indicate that
            // they have been potted permanently.
            for (i = ballsOnTableCount; i < ballsOnTableAndPottedCount; i++)
                balls[i].potStatus = 3;
            
            // Now determine the next state of the game.

            if (m_currentColour === 1) {
                // If red is the current colour...
                if (currentColourPottedCount === 0 || foulPointsScored !== 0) {
                    // If a foul was committed or no balls were potted, the colour for the next shot is
                    // red if there are reds remaining on the table, otherwise it is yellow.
                    if (m_totalRedsPotted === 15)
                        m_currentColour = 2;

                    if (foulPointsScored !== 0) {
                        m_replayAfterFoul = false;
                        m_gameState = GameState.CHOOSE_FOUL_PLAYER;
                    }
                    else {
                        _setDefaultCuePosition();
                        m_gameState = GameState.CUE_AIM;
                    }
                }
                else {
                    // Otherwise, allow the player to choose the colour (other than red) for the next shot.
                    m_shootingColourAfterRed = true;
                    m_currentColour = 2;
                    m_gameState = GameState.CHOOSE_COLOUR;
                }
            }
            else {
                // If the current colour is not red...
                if (m_shootingColourAfterRed) {
                    // If the player has attempted a shot at a colour ball after a red, the colour
                    // for the next shot is red if there are reds on the table, otherwise it is yellow.
                    m_shootingColourAfterRed = false;
                    m_currentColour = (m_totalRedsPotted === 15) ? 2 : 1;
                }
                else {
                    // If the shot at the colour ball is after all reds have been potted, the colour
                    // for the next shot is the one of the next highest value if the colour is legally potted.
                    // Otherwise the colour for the next shot is unchanged.
                    m_currentColour += int(currentColourPottedCount !== 0 && foulPointsScored === 0);
                }
                
                if (foulPointsScored !== 0) {
                    m_replayAfterFoul = false;
                    m_gameState = GameState.CHOOSE_FOUL_PLAYER;
                }
                else {
                    _setDefaultCuePosition();
                    m_gameState = GameState.CUE_AIM;
                }
            }
            
            if (foulPointsScored !== 0 || currentColourPottedCount === 0) {
                // Switch to the other player if a foul was committed or no balls of the active
                // colour potted.
                m_currentPlayer = 1 - m_currentPlayer;
            }
        }
        
        /**
         * Sets the cue tip position and angle to their default values.
         */
        private function _setDefaultCuePosition(): void {
            m_cueTipDistance = 20;
            m_cueDirX = 1;
            m_cueDirY = 0;
            _predictTargetBall();
        }
        
        /**
         * Determines which ball would be hit by the cue ball first, given the direction of
         * the shot. Also computes the predicted point of impact and direction of the target ball
         * when it is hit.
         */
        private function _predictTargetBall(): void {
            var ball: Ball;
            var cueBall: Ball = balls[0];
            var targetTDist: Number, targetNDist: Number;
            var rx: Number, ry: Number;

            m_predictedTargetBall = null;
            
            for (var i: int = 1; i < m_ballsOnTableCount; i++) {
                ball = balls[i];

                rx = ball.x - cueBall.x;
                ry = ball.y - cueBall.y;

                var tDist: Number = rx * m_cueDirX + ry * m_cueDirY;
                var nDist: Number = Math.abs(rx * m_cueDirY - ry * m_cueDirX);
                
                if (tDist < 0 || nDist >= 25.2)
                    continue;

                if (m_predictedTargetBall === null || targetTDist > tDist) {
                    targetTDist = tDist;
                    targetNDist = nDist;
                    m_predictedTargetBall = ball;
                }
            }
            
            if (m_predictedTargetBall === null)
                return;
            
            var impactDist: Number = targetTDist - Math.sqrt(635.04 - targetNDist * targetNDist);
            m_predictedTargetImpactX = cueBall.x + m_cueDirX * impactDist;
            m_predictedTargetImpactY = cueBall.y + m_cueDirY * impactDist;
            m_predictedTargetDirX = (m_predictedTargetBall.x - m_predictedTargetImpactX) * 0.03968253968253967;
            m_predictedTargetDirY = (m_predictedTargetBall.y - m_predictedTargetImpactY) * 0.03968253968253967;
        }
        
        /**
         * Checks if the given ball can be placed at a particular spot on the table without colliding
         * with another ball.
         * 
         * @param ball The ball which is to be placed on the new spot.
         * @param spotX The x coordinate of the spot to be checked.
         * @param newY The y coordinate of the spot to be checked.
         * @param baulkOnly Set to true to check only the balls in the baulk.
         * @return The ball with which the target ball may collide when placed on the spot, or null if
         * the spot is not occupied.
         */
        private function _checkCollisionForSpotting(ball: Ball, spotX: Number, spotY: Number, baulkOnly: Boolean): Ball {
            var count: int = m_ballsOnTableCount;
            for (var i: int = 0; i < count; i++) {
                var targetBall: Ball = balls[i];
                if (targetBall === ball || targetBall.potStatus !== 0 || (baulkOnly && targetBall.x > 366.4))
                    continue;

                var targetDistX: Number = targetBall.x - spotX;
                var targetDistY: Number = targetBall.y - spotY;

                if (targetDistX * targetDistX + targetDistY * targetDistY < 635.04)
                    return targetBall;
            }
            return null;
        }
        
        /**
         * Spots the cue ball at a random unoccupied spot in the 'D'. (for example, after the
         * cue ball is potted in a foul, or at the start of a frame)
         */
        public function spotCueBallInD(): void {
            var cueBall: Ball = balls[0];

            while (true) {
                // This algorithm generates uniformly distributed random points in the semicircle and
                // checks if they are occupied, until it finds an unoccupied point. (The radius is actually
                // 140.2, but an allowance of .01 is kept here)
                var rad: Number = Math.sqrt(Math.random()) * 140.19;
                var sinTheta: Number = Math.sin((Math.random() * 2 - 1) * 1.570796326794897);
                var newX: Number = 353.8 - rad * Math.sqrt(1 - sinTheta * sinTheta);
                var newY: Number = 426.7 + rad * sinTheta;

                if (!_checkCollisionForSpotting(cueBall, newX, newY, true)) {
                    cueBall.x = newX;
                    cueBall.y = newY;
                    cueBall.potStatus = 0;
                    return;
                }
            }
        }
        
        /**
         * Spots a colour ball.
         * 
         * @param ball The colour ball to be spotted.
         */
        private function _spotColourBall(colourBall: Ball): void {
            var occupiedBall: Ball = null;
            var colour: int = colourBall.colour;
            var spotX: Number, spotY: Number;
            var i: int, j: int;
            
            // First check if the ball's original spot is occupied.
            spotX = initialBallPositions[int((colour - 1) << 1)];
            spotY = initialBallPositions[int(((colour - 1) << 1) + 1)];
            occupiedBall = _checkCollisionForSpotting(colourBall, spotX, spotY, false);
            
            if (occupiedBall) {
                // Ball's original spot is occupied. Check all other colour spots in descending order.
                for (j = 7; j >= 2; j--) {
                    if (j === colour)
                        continue;
                    spotX = initialBallPositions[int((j - 1) << 1)];
                    spotY = initialBallPositions[int(((j - 1) << 1) + 1)];
                    if (!_checkCollisionForSpotting(colourBall, spotX, spotY, false))
                        break;
                }

                if (j === 1) {
                    // None of the colour spots are available.
                    // According to the rules, the ball now has to be spotted on the horizontal line
                    // from the ball's original spot to the right end of the table, as close as
                    // possible to the original spot.
                    spotY = initialBallPositions[int(((colour - 1) << 1) + 1)];
                    var dy: Number;

                    while (occupiedBall !== null) {
                        dy = spotY - occupiedBall.y;
                        // An allowance of 0.01 is kept here to ensure that no collision is detected with
                        // the same ball (due to floating point error) that would result in an infinite loop.
                        spotX = occupiedBall.x + Math.sqrt(635.04 - dy * dy) + 0.01;
                        if (spotX > 1700.5)  // Reached the edge of the table!
                            break;
                        occupiedBall = _checkCollisionForSpotting(colourBall, spotX, spotY, false);
                    }

                    if (occupiedBall !== null) {
                        // If the ball is still unable to be spotted (this can happen only for pink
                        // and black balls), it must as a last resort be spotted on the centre line,
                        // to the left of the original spot and as close to it as possible.
                        spotY = 426.7;
                        spotX = initialBallPositions[int((colour - 1) << 1)];
                        occupiedBall = _checkCollisionForSpotting(colourBall, spotX, spotY, false);
                        while (occupiedBall) {
                            dy = spotY - occupiedBall.y;
                            spotX = occupiedBall.x - Math.sqrt(635.04 - dy * dy) - 0.01;
                            occupiedBall = _checkCollisionForSpotting(colourBall, spotX, spotY, false);
                        }
                    }
                }
            }
            
            colourBall.x = spotX;
            colourBall.y = spotY;
            colourBall.potStatus = 0;
        }
        
        /**
         * Calculates the future state of the ball after a time interval, taking into account friction
         * with the table. The state after the time interval is stored in the ball's x2, y2, vx2 and vy2
         * fields.
         * 
         * @param ball The Ball object.
         * @param dt The time interval.
         */
        private function _calculateExpectedBallState(ball: Ball, dt: Number): void {
            // The friction model used by this function:
            // dv/dt = -(a0*vt + a1*(v-vt))   [v > vt]
            // dv/dt = -a0*v                  [v < vt]
            // The parameter values used are:
            // a0 = 0.048, a1 = 0.000045, vt = 0.006
            // Derived values:
            // (a0-a1)*vt = 0.00028773
            var speed: Number = Math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy);
            var accX: Number, accY: Number, temp: Number;
            if (speed < 0.006) {
                accX = -0.048 * ball.vx;
                accY = -0.048 * ball.vy;
            }
            else {
                temp = -0.00028773 / speed - 0.000045;
                accX = temp * ball.vx;
                accY = temp * ball.vy;
            }

            temp = 0.5 * dt * dt;
            ball.x2 = ball.x + ball.vx * dt + accX * temp;
            ball.y2 = ball.y + ball.vy * dt + accY * temp;
            ball.vx2 = ball.vx + accX * dt;
            ball.vy2 = ball.vy + accY * dt;
            
            // Truncate very small velocities to zero.
            if (Math.abs(ball.vx2) < 1E-6)
                ball.vx2 = 0;
            if (Math.abs(ball.vy2) < 1E-6)
                ball.vy2 = 0;
        }
        
        /**
         * A function used for solving quadratic equations to compute collision RCTs.
         * This checks for a root of the quadratic equation ax^2+bx+c such that 0<=x<=1. If both
         * roots are in this range, the lesser value is returned.
         * 
         * @return The root of the quadratic equation ax^2+bx+c such that 0<=x<=1. If no root in this range
         * can be found, -1 is returned.
         */
        private static function _quadSolve(a: Number, b: Number, c: Number): Number {
            var root: Number;
            if (Math.abs(a) < 1E-12) {
                if (Math.abs(b) < 1E-12)
                    return -1;

                if (b < 0) {
                    b = -b;
                    c = -c;
                }

                if (c > 0 || -c > b)
                    return -1;

                root = -c / b;
            }
            else {
                if ((c > 0 && b > 0) || (b < -2 * a && a + b + c > 0))
                    return -1;

                var d: Number = b * b - 4 * a * c;
                if (d < 0)
                    return -1;

                d = Math.sqrt(d);

                root = -(b + d)
                if (root < -1E-8)
                    root = d - b;
                if (root > 2 * a)
                    return -1;

                root /= 2 * a;
            }

            if (root < 0 && root >= -1E-8)
                root = 0;

            return root;
        }
        
        /**
         * Check for collisions between a ball and a cushion.
         * If a collision was detected, the ball's vxc and vyc fields and the _minRCT field are set to
         * the appropriate values.
         * 
         * @param ball The ball to check.
         * 
         * @return True if a collision was detected, false otherwise.
         */
        private function _checkBallCushionCollisions(ball: Ball): Boolean {
            // Determine which cushion the ball can possibly collide with.
            var cushionIndex: int = -1;
            if (ball.x2 <= 12.6)
                cushionIndex = 0;   // Left cushion
            else if (ball.x2 >= 1700.5)
                cushionIndex = 3;   // Right cushion
            else if (ball.y2 <= 12.6)
                cushionIndex = 2 - int(ball.x2 < 856.55)   // Top-left or top-right, depending on table half
            else if (ball.y2 >= 840.8)
                cushionIndex = 4 + int(ball.x2 < 856.55)   // Bottom-left or bottom-right, depending on table half
                
            if (cushionIndex === -1)   // Ball cannot possibly collide with any cushion
                return false;
            
            var cushion: Cushion = cushions[cushionIndex];
            var i: int;
            var startX: Number, startY: Number, endRX: Number, endRY: Number, normalX: Number, normalY: Number;
            var impactX: Number, impactY: Number;
            
            // COR for ball-cushion collisions is set as 0.87
            
            for (i = 0; i < 6; i += 2) {
                startX = cushion.points[i]
                startY = cushion.points[int(i + 1)]
                normalX = cushion.normals[i];
                normalY = cushion.normals[int(i + 1)];
                
                // Compute the distance from the centre of the ball to each cushion segment.
                var p1: Number = (ball.x - startX) * normalX + (ball.y - startY) * normalY;
                var p2: Number = (ball.x2 - startX) * normalX + (ball.y2 - startY) * normalY;

                // No collision if the final distance is greater than the ball radius, greater then
                // the initial distance or the change is insignificant.
                if (p2 > 12.6 || p2 > p1 || p1 - p2 <= 1E-8)
                    continue;
                    
                // Use linear interpolation to compute the relative collision time.
                // Only account for this collision if no other collision occured earlier.
                var rct: Number = (12.6 - p1) / (p2 - p1);
                if (rct >= m_minRCT || rct < -1E-8)
                    continue;
                
                // For a cushion segment, say AB, calculate the point of impact P on the line
                // containing AB. To check if P lies inside the segment AB, use the two conditions
                // |AP| <= |AB| and AP.AB >= 0 (where '.' is the dot product)
                impactX = ball.x + rct * (ball.x2 - ball.x);
                impactY = ball.y + rct * (ball.y2 - ball.y);

                var impactRX: Number = impactX - 12.6 * normalX - startX;
                var impactRY: Number = impactY - 12.6 * normalY - startY;

                endRX = cushion.points[int(i + 2)] - startX;
                endRY = cushion.points[int(i + 3)] - startY;

                if (impactRX * impactRX + impactRY * impactRY <= endRX * endRX + endRY * endRY
                    && impactRX * endRX + impactRY * endRY >= 0)
                {
                    // Collision detected!
                    m_minRCT = rct;
                    ball.vxc = ball.vx + rct * (ball.vx2 - ball.vx);
                    ball.vyc = ball.vy + rct * (ball.vy2 - ball.vy);
                    p2 = (ball.vxc * normalX + ball.vyc * normalY) * -1.87;
                    ball.vxc += p2 * normalX;
                    ball.vyc += p2 * normalY;
                    ball.potStatus = 0;
                    return true;
                }
            }
            
            // Check cushion corners...
            endRX = ball.x2 - ball.x;
            endRY = ball.y2 - ball.y;

            for (i = 2; i < 6; i += 2) {
                startX = ball.x - cushion.points[i];
                startY = ball.y - cushion.points[int(i + 1)];

                rct = _quadSolve(
                    endRX * endRX + endRY * endRY,
                    2 * (startX * endRX + startY * endRY),
                    startX * startX + startY * startY - 158.76
                );
                
                if (rct !== -1 && rct < m_minRCT) {
                    // Ball has collided with the corner. Check if it is moving towards or away from it.
                    normalX = cushion.cornerNormals[i];
                    normalY = cushion.cornerNormals[int(i + 1)];

                    ball.vxc = ball.vx + rct * (ball.vx2 - ball.vx);
                    ball.vyc = ball.vy + rct * (ball.vy2 - ball.vy);

                    p2 = ball.vxc * normalX + ball.vyc * normalY;

                    if (p2 <= -1E-8) {
                        // Ball is going towards the corner normal, so a collision is detected.
                        ball.vxc -= p2 * normalX * 1.87;
                        ball.vyc -= p2 * normalY * 1.87;
                        ball.potStatus = 0;
                        m_minRCT = rct;
                        return true;
                    }
                }
            }
            
            return false;
            
        }
        
        /**
         * Checks for a ball entering a pocket.
         * If a pocket entry is detected, the _minRCT field will be set to the appropriate values.
         * 
         * @param ball The ball to check.
         * 
         * @return True if the ball will enter any of the pockets, false otherwise.
         */
        private function _checkBallPocketEntry(ball: Ball): Boolean {
            var centres: Vector.<Number> = pocketCentres;
            var dx: Number = ball.x2 - ball.x;
            var dy: Number = ball.y2 - ball.y;
            var a: Number = dx * dx + dy * dy;
            
            for (var i: int = 0, n: int = pocketCentres.length; i < n; i += 2) {
                // Check for collision with each pocket. A potting occurs if the distance
                // between the ball centre and pocket centre is less than the pocket radius.

                var x1: Number = ball.x - centres[i];
                var y1: Number = ball.y - centres[int(i + 1)];

                var rct: Number = _quadSolve(a, 2 * (x1 * dx + y1 * dy), x1 * x1 + y1 * y1 - 506.25);

                if (rct !== -1) {
                    if (rct < m_minRCT) {
                        m_minRCT = rct;
                        ball.potStatus = 1;
                        return true;
                    }
                    // A ball can never contact two pockets simultaneously, so exit.
                    return false;
                }
            }

            return false;
        }
        
        /**
         * Checks for collisions between two balls.
         * If a collision is detected, the vxc and vyc fields of both Ball objects and the _minRCT field
         * will be set to the appropriate values.
         * 
         * @param ball1 The first ball
         * @param ball2 The second ball.
         * 
         * @return True if there is a collision between the two balls, false if there is no collision.
         */
        private function _checkTwoBallCollision(ball1: Ball, ball2: Ball): Boolean {
            if (ball1.vx === 0 && ball1.vy === 0 && ball2.vx === 0 && ball2.vy === 0)
                return false;
                
            // Find the relative collision time.            
            var r1x: Number = ball2.x - ball1.x;
            var r1y: Number = ball2.y - ball1.y;
            var drx: Number = (ball2.x2 - ball1.x2) - r1x;
            var dry: Number = (ball2.y2 - ball1.y2) - r1y;
            var rct: Number;

            if (r1x * r1x + r1y * r1y < 635.04) {
                rct = 0;
            }
            else {
                rct = _quadSolve(
                    drx * drx + dry * dry,
                    2 * (r1x * drx + r1y * dry),
                    r1x * r1x + r1y * r1y - 635.04
                );
            }
            
            if (rct === -1 || rct > m_minRCT)
                return false;
            
            // Calculate the (pre-collision) velocities of the two balls normal to the line
            // of contact.
            var normalX: Number = (r1x + rct * drx);
            var normalY: Number = (r1y + rct * dry);

            var k: Number = 1 / Math.sqrt(normalX * normalX + normalY * normalY);
            normalX *= k;
            normalY *= k;
            
            var u1x: Number = ball1.vx + rct * (ball1.vx2 - ball1.vx);
            var u1y: Number = ball1.vy + rct * (ball1.vy2 - ball1.vy);
            var u2x: Number = ball2.vx + rct * (ball2.vx2 - ball2.vx);
            var u2y: Number = ball2.vy + rct * (ball2.vy2 - ball2.vy);
            var u1n: Number = u1x * normalX + u1y * normalY;
            var u2n: Number = u2x * normalX + u2y * normalY;

            if (u2n >= u1n)
                return false;   // Balls are moving away from each other, so no collision
                
            // The COR for ball-ball collisions is currently set as e=0.8
            // (1-0.8)/2 = 0.1, (1+0.8)/2 = 0.9
            // Now calculate the post-collision velocities
            var v1n: Number = u1n * 0.1 + u2n * 0.9;
            var v2n: Number = u1n * 0.9 + u2n * 0.1;

            ball1.vxc = u1x + (v1n - u1n) * normalX;
            ball1.vyc = u1y + (v1n - u1n) * normalY;
            ball2.vxc = u2x + (v2n - u2n) * normalX;
            ball2.vyc = u2y + (v2n - u2n) * normalY;

            m_minRCT = rct;
            return true;
        }
        
        /*   FOR DEBUGGING ONLY   */
        private function _logTableState(): void {
            var balls: Vector.<Ball> = this.balls;
            trace("------- Table log ---------");
            for (var i: int = 0; i < 22; i++) {
                var b: Ball = balls[i];
                if (b.potStatus === 0) {
                    trace(
                        "Ball #" + i + " (colour " + b.colour
                        + ") x = " + b.x.toFixed(15)
                        + ", y = " + b.y.toFixed(15)
                        + ", vx = " + b.vx.toFixed(15)
                        + ", vy = " + b.vy.toFixed(15)
                    );
                }
                else {
                    trace("Ball #" + i + " (colour " + b.colour + "): potted");
                }
            }
            trace();
        }
    }

}