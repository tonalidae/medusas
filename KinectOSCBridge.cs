using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Kinect;
using OSC.NET;

/// <summary>
/// Kinect v1 to OSC Bridge
/// Captures hand tracking from Kinect v1 and sends to Processing via OSC
/// OSC Target: 127.0.0.1:12000
/// </summary>
public class KinectOSCBridge
{
    // Kinect sensor
    private KinectSensor kinectSensor;
    
    // OSC sender
    private OSCTransmitter oscTransmitter;
    private const string OSC_IP = "127.0.0.1";
    private const int OSC_PORT = 12000;

    // Processing-side expectations
    private const int MAX_HANDS = 6;
    private const float NEAR_M = 0.8f;
    private const float FAR_M  = 4.0f;

    // Motion energy (for /arm_energy)
    private float prevXN = 0f;
    private float prevYN = 0f;
    private float prevZM = 0f;
    private bool hasPrev = false;
    private float armEnergy = 0f;
    private const float ARM_ENERGY_SMOOTH = 0.25f;
    private const float ARM_ENERGY_GAIN  = 8.0f;

    // Debug throttling
    private int lastDebugTick = 0;
    
    // Tracking state
    private Dictionary<JointType, Joint> joints = new Dictionary<JointType, Joint>();
    private Dictionary<JointType, Vector2> smoothedJoints = new Dictionary<JointType, Vector2>();
    private float smoothingAlpha = 0.2f; // Low-pass filter for jitter reduction
    
    // Hand tracking
    private Vector2 leftHandPos = Vector2.Zero;
    private Vector2 rightHandPos = Vector2.Zero;
    private Vector2 leftHandSmoothed = Vector2.Zero;
    private Vector2 rightHandSmoothed = Vector2.Zero;
    private bool leftHandTracking = false;
    private bool rightHandTracking = false;
    
    // Gesture detection (tap/click)
    private Vector2 leftHandPrevPos = Vector2.Zero;
    private Vector2 rightHandPrevPos = Vector2.Zero;
    private float tapThreshold = 0.3f; // Sudden movement threshold
    private int tapCooldown = 0;
    private const int TAP_COOLDOWN_FRAMES = 30;
    
    // Screen/depth mapping
    private int screenWidth = 1920;
    private int screenHeight = 1080;
    private DepthImageFrame depthFrame;
    private ColorImageFrame colorFrame;
    
    public KinectOSCBridge(int width = 1920, int height = 1080)
    {
        screenWidth = width;
        screenHeight = height;
        InitializeKinect();
        InitializeOSC();
    }
    
    /// <summary>
    /// Initialize Kinect v1 sensor
    /// </summary>
    private void InitializeKinect()
    {
        try
        {
            // Get the first kinect sensor
            KinectSensor.KinectSensors.StatusChanged += (s, e) =>
            {
                if (e.Sensor.Status == KinectStatus.Connected && kinectSensor == null)
                {
                    kinectSensor = e.Sensor;
                    StartKinect();
                }
            };
            
            // Use existing sensor or wait for one
            kinectSensor = KinectSensor.KinectSensors.FirstOrDefault(s => s.Status == KinectStatus.Connected);
            
            if (kinectSensor != null)
            {
                StartKinect();
            }
            else
            {
                Console.WriteLine("No Kinect v1 sensor found!");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error initializing Kinect: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Start Kinect skeleton tracking
    /// </summary>
    private void StartKinect()
    {
        if (kinectSensor == null) return;
        
        try
        {
            // Enable skeleton stream
            kinectSensor.SkeletonStream.Enable();
            kinectSensor.SkeletonFrameReady += OnSkeletonFrameReady;
            
            // Enable depth stream for hand positioning
            kinectSensor.DepthStream.Enable(DepthImageFormat.Resolution320x240Fps30);
            kinectSensor.DepthFrameReady += OnDepthFrameReady;
            
            kinectSensor.Start();
            Console.WriteLine("Kinect v1 started successfully");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error starting Kinect: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Initialize OSC connection
    /// </summary>
    private void InitializeOSC()
    {
        try
        {
            oscTransmitter = new OSCTransmitter(OSC_IP, OSC_PORT);
            Console.WriteLine($"OSC Transmitter initialized: {OSC_IP}:{OSC_PORT}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error initializing OSC: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Handle skeleton frame (joint tracking)
    /// </summary>
    private void OnSkeletonFrameReady(object sender, SkeletonFrameReadyEventArgs e)
    {
        try
        {
            using (SkeletonFrame frame = e.OpenSkeletonFrame())
            {
                if (frame == null) return;
                
                Skeleton[] skeletons = new Skeleton[frame.SkeletonArrayLength];
                frame.CopySkeletonDataTo(skeletons);

                // Debug: show whether Kinect is seeing skeletons at all
                int trackedCount = skeletons.Count(s => s != null && s.TrackingState == SkeletonTrackingState.Tracked);
                int positionOnlyCount = skeletons.Count(s => s != null && s.TrackingState == SkeletonTrackingState.PositionOnly);
                int notTrackedCount = skeletons.Count(s => s != null && s.TrackingState == SkeletonTrackingState.NotTracked);

                int now = Environment.TickCount;
                if (now - lastDebugTick > 1000)
                {
                    lastDebugTick = now;
                    Console.WriteLine($"Skeleton states: Tracked={trackedCount}, PositionOnly={positionOnlyCount}, NotTracked={notTrackedCount}");
                }
                
                // Get first tracked skeleton
                Skeleton skeleton = skeletons.FirstOrDefault(s => s.TrackingState == SkeletonTrackingState.Tracked);
                
                if (skeleton != null)
                {
                    ProcessSkeleton(skeleton);
                    SendOSCUpdate();
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in skeleton frame: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Handle depth frame (for hand position mapping)
    /// </summary>
    private void OnDepthFrameReady(object sender, DepthImageFrameReadyEventArgs e)
    {
        try
        {
            using (DepthImageFrame frame = e.OpenDepthImageFrame())
            {
                if (frame != null)
                {
                    depthFrame = frame;
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in depth frame: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Process skeleton data and extract hand positions
    /// </summary>
    private void ProcessSkeleton(Skeleton skeleton)
    {
        // Get hand joints
        Joint leftHand = skeleton.Joints[JointType.HandLeft];
        Joint rightHand = skeleton.Joints[JointType.HandRight];
        
        // Only process if hands are tracked
        if (leftHand.TrackingState == JointTrackingState.Tracked)
        {
            leftHandTracking = true;
            leftHandPos = ConvertJointToScreen(leftHand);
            leftHandSmoothed = SmoothPosition(leftHandPos, leftHandSmoothed);
            DetectTap(leftHandPos, leftHandPrevPos, true);
            leftHandPrevPos = leftHandPos;
        }
        else
        {
            leftHandTracking = false;
        }
        
        if (rightHand.TrackingState == JointTrackingState.Tracked)
        {
            rightHandTracking = true;
            rightHandPos = ConvertJointToScreen(rightHand);
            rightHandSmoothed = SmoothPosition(rightHandPos, rightHandSmoothed);
            DetectTap(rightHandPos, rightHandPrevPos, false);
            rightHandPrevPos = rightHandPos;
        }
        else
        {
            rightHandTracking = false;
        }
        
        // Store all joints for later use
        joints.Clear();
        foreach (Joint joint in skeleton.Joints)
        {
            joints[joint.JointType] = joint;
        }
    }
    
    /// <summary>
    /// Convert Kinect joint position to screen coordinates
    /// </summary>
    private Vector2 ConvertJointToScreen(Joint joint)
    {
        if (kinectSensor == null) return Vector2.Zero;
        
        try
        {
            // Normalize coordinates (-1 to 1)
            float x = joint.Position.X;
            float y = joint.Position.Y;
            
            // Map to screen (flip X for natural interaction)
            float screenX = (1.0f - (x + 1.0f) * 0.5f) * screenWidth;
            float screenY = (1.0f - (y + 1.0f) * 0.5f) * screenHeight;
            
            // Clamp to screen bounds
            screenX = Math.Max(0, Math.Min(screenWidth, screenX));
            screenY = Math.Max(0, Math.Min(screenHeight, screenY));
            
            return new Vector2((int)screenX, (int)screenY);
        }
        catch
        {
            return Vector2.Zero;
        }
    }
    
    /// <summary>
    /// Apply low-pass smoothing filter to reduce jitter
    /// </summary>
    private Vector2 SmoothPosition(Vector2 current, Vector2 previous)
    {
        if (previous == Vector2.Zero) return current;
        
        return new Vector2(
            (int)(previous.X + smoothingAlpha * (current.X - previous.X)),
            (int)(previous.Y + smoothingAlpha * (current.Y - previous.Y))
        );
    }
    
    /// <summary>
    /// Detect tap/click gesture from sudden hand movement
    /// </summary>
    private void DetectTap(Vector2 current, Vector2 previous, bool isLeftHand)
    {
        if (tapCooldown > 0)
        {
            tapCooldown--;
            return;
        }
        
        float distance = Vector2.Distance(current, previous);
        
        // Sudden movement = tap
        if (distance > tapThreshold * screenWidth)
        {
            SendOSCTap(current, isLeftHand);
            tapCooldown = TAP_COOLDOWN_FRAMES;
            Console.WriteLine($"Tap detected: {(isLeftHand ? "Left" : "Right")} hand at {current}");
        }
    }
    
    /// <summary>
    /// Send OSC update with current hand positions (Processing-compatible)
    /// </summary>
    private void SendOSCUpdate()
    {
        try
        {
            if (!(rightHandTracking || leftHandTracking)) return;

            // Choose primary hand (right preferred)
            bool useRight = rightHandTracking;
            Vector2 primaryHand = useRight ? rightHandSmoothed : leftHandSmoothed;

            // Normalized screen coords (0..1) for Processing
            float xN = screenWidth > 0 ? (primaryHand.X / (float)screenWidth) : 0f;
            float yN = screenHeight > 0 ? (primaryHand.Y / (float)screenHeight) : 0f;
            xN = Clamp01(xN);
            yN = Clamp01(yN);

            // Depth in meters from Kinect joint (more reliable than cached depth frame)
            JointType jt = useRight ? JointType.HandRight : JointType.HandLeft;
            float zM = 2.0f;
            if (joints.ContainsKey(jt))
            {
                zM = joints[jt].Position.Z;
            }
            zM = Clamp(zM, NEAR_M, FAR_M);

            // Proximity: 1 near, 0 far
            float prox = Clamp01((FAR_M - zM) / (FAR_M - NEAR_M));

            // Processing expects zNorm near=-0.2, far=0.4
            float zNorm = Lerp(0.4f, -0.2f, prox);

            // Motion energy (speed) for /arm_energy
            float energyInstant = 0f;
            if (hasPrev)
            {
                float dx = xN - prevXN;
                float dy = yN - prevYN;
                float dz = zM - prevZM;
                float speed = (float)Math.Sqrt(dx * dx + dy * dy + (dz * 0.35f) * (dz * 0.35f));
                energyInstant = speed * ARM_ENERGY_GAIN;
            }
            armEnergy = Lerp(armEnergy, energyInstant, ARM_ENERGY_SMOOTH);
            prevXN = xN;
            prevYN = yN;
            prevZM = zM;
            hasPrev = true;

            // ===== Send Processing-compatible messages =====
            // /hands: 6 slots, each slot = [present, x, y, zNorm]
            OSCMessage handsMsg = new OSCMessage("/hands");
            for (int i = 0; i < MAX_HANDS; i++)
            {
                if (i == 0)
                {
                    handsMsg.Append(1.0f);
                    handsMsg.Append(xN);
                    handsMsg.Append(yN);
                    handsMsg.Append(zNorm);
                }
                else
                {
                    handsMsg.Append(0.0f);
                    handsMsg.Append(0.0f);
                    handsMsg.Append(0.0f);
                    handsMsg.Append(0.0f);
                }
            }
            oscTransmitter.Send(handsMsg);

            // /hand_size: 6 floats
            OSCMessage sizeMsg = new OSCMessage("/hand_size");
            sizeMsg.Append(prox);
            for (int i = 1; i < MAX_HANDS; i++) sizeMsg.Append(0.0f);
            oscTransmitter.Send(sizeMsg);

            // /arm_energy: 6 floats
            OSCMessage energyMsg = new OSCMessage("/arm_energy");
            energyMsg.Append(armEnergy);
            for (int i = 1; i < MAX_HANDS; i++) energyMsg.Append(0.0f);
            oscTransmitter.Send(energyMsg);

            // Legacy /hand: x,y,zNorm
            OSCMessage legacyHand = new OSCMessage("/hand");
            legacyHand.Append(xN);
            legacyHand.Append(yN);
            legacyHand.Append(zNorm);
            oscTransmitter.Send(legacyHand);

            // Keep your original namespace messages too (optional)
            OSCMessage msg = new OSCMessage("/kinect/hand");
            msg.Append((int)primaryHand.X);
            msg.Append((int)primaryHand.Y);
            msg.Append(useRight ? 1 : 0);
            oscTransmitter.Send(msg);

            OSCMessage proximityMsg = new OSCMessage("/kinect/proximity");
            proximityMsg.Append(prox);
            oscTransmitter.Send(proximityMsg);

            // Debug (throttled)
            int now = Environment.TickCount;
            if (now - lastDebugTick > 1000)
            {
                // lastDebugTick is also used by skeleton-state prints; ok to share
                Console.WriteLine($"OSC /hands slot0: x={xN:0.000} y={yN:0.000} zNorm={zNorm:0.000} prox={prox:0.000} energy={armEnergy:0.000}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error sending OSC update: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Send OSC tap/click event
    /// </summary>
    private void SendOSCTap(Vector2 position, bool isLeftHand)
    {
        try
        {
            OSCMessage msg = new OSCMessage("/kinect/tap");
            msg.Append((int)position.X);
            msg.Append((int)position.Y);
            msg.Append(isLeftHand ? 0 : 1); // 0=left, 1=right
            oscTransmitter.Send(msg);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error sending OSC tap: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Get current left hand position (screen coordinates)
    /// </summary>
    public Vector2 GetLeftHandPosition()
    {
        return leftHandSmoothed;
    }
    
    /// <summary>
    /// Get current right hand position (screen coordinates)
    /// </summary>
    public Vector2 GetRightHandPosition()
    {
        return rightHandSmoothed;
    }
    
    /// <summary>
    /// Is left hand being tracked
    /// </summary>
    public bool IsLeftHandTracking()
    {
        return leftHandTracking;
    }
    
    /// <summary>
    /// Is right hand being tracked
    /// </summary>
    public bool IsRightHandTracking()
    {
        return rightHandTracking;
    }
    
    /// <summary>
    /// Shutdown Kinect and OSC
    /// </summary>
    public void Shutdown()
    {
        if (kinectSensor != null)
        {
            kinectSensor.Stop();
            kinectSensor.Dispose();
        }
        Console.WriteLine("Kinect OSC Bridge shut down");
    }
}

/// <summary>
/// Simple Vector2 implementation (if not using XNA)
/// </summary>
public struct Vector2
{
    public int X { get; set; }
    public int Y { get; set; }
    
    public static Vector2 Zero = new Vector2(0, 0);
    
    public Vector2(int x, int y)
    {
        X = x;
        Y = y;
    }
    
    public static float Distance(Vector2 a, Vector2 b)
    {
        float dx = a.X - b.X;
        float dy = a.Y - b.Y;
        return (float)Math.Sqrt(dx * dx + dy * dy);
    }
    
    public static bool operator ==(Vector2 a, Vector2 b)
    {
        return a.X == b.X && a.Y == b.Y;
    }
    
    public static bool operator !=(Vector2 a, Vector2 b)
    {
        return !(a == b);
    }
    
    public override bool Equals(object obj)
    {
        if (!(obj is Vector2)) return false;
        Vector2 other = (Vector2)obj;
        return this == other;
    }
    
    public override int GetHashCode()
    {
        return X.GetHashCode() ^ Y.GetHashCode();
    }
    
    public override string ToString()
    {
        return $"({X}, {Y})";
    }
}

/// <summary>
/// Example usage / Main program
/// </summary>
public class Program
{
    public static void Main(string[] args)
    {
        Console.WriteLine("Kinect v1 OSC Bridge Starting...");
        
        // Initialize bridge
        KinectOSCBridge bridge = new KinectOSCBridge(1920, 1080);
        
        // Keep running
        Console.WriteLine("Press ESC to exit...");
        while (Console.ReadKey(true).Key != ConsoleKey.Escape)
        {
            // Main loop would run here
        }
        
        bridge.Shutdown();
    }
}

    private static float Clamp01(float v)
    {
        if (v < 0f) return 0f;
        if (v > 1f) return 1f;
        return v;
    }

    private static float Clamp(float v, float lo, float hi)
    {
        if (v < lo) return lo;
        if (v > hi) return hi;
        return v;
    }

    private static float Lerp(float a, float b, float t)
    {
        return a + (b - a) * t;
    }