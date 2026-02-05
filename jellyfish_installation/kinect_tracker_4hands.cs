using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using Microsoft.Kinect;
using Rug.Osc;

class Program
{
	// ===== OSC CONFIG =====
	const string OSC_IP = "127.0.0.1";
	const int OSC_PORT = 12000;

	// ===== TRACKING CONFIG =====
	const int MAX_HANDS = 6;               // must match Processing MAX_HANDS
	const int ACTIVE_HAND_SLOTS = 4;       // 2 people * 2 hands
	const int MAX_PEOPLE = 2;              // Kinect v1: 2 tracked skeletons
	const int SLOT_MISS_FORGET = 12;       // frames until a slot is cleared
	const float ARM_ENERGY_SMOOTH = 0.25f; // smoothing for /arm_energy (0..1)
	const float ARM_ENERGY_GAIN = 8.0f;    // scale energy into a nicer range

	// ===== DEPTH MAPPING (meters) =====
	// Screen plane distance from Kinect (your setup ~2.0m).
	const float SCREEN_M = 3.95f;
	// Distance in front of the screen that maps to "far" (0.0 proximity).
	const float FRONT_RANGE_M = 0.9f;

	// ===== OPTIONAL MIRRORING =====
	const bool FLIP_X = false;
	const bool FLIP_Y = false;

    static KinectSensor sensor;
    static OscSender osc;
    static DateTime lastStatusLog = DateTime.MinValue;
    static DateTime lastHandLog = DateTime.MinValue;

	// Person slot: stable assignment by TrackingId
	class PersonSlot
	{
		public int TrackingId = 0;
		public int MissFrames = 0;
	}

	// Hand slot: per-hand energy/velocity
	class HandState
	{
		public float PrevXN = 0, PrevYN = 0, PrevZM = 0;
		public bool HasPrev = false;
		public float ArmEnergy = 0;
	}

	static PersonSlot[] people = Enumerable.Range(0, MAX_PEOPLE).Select(_ => new PersonSlot()).ToArray();
	static HandState[] handStates = Enumerable.Range(0, ACTIVE_HAND_SLOTS).Select(_ => new HandState()).ToArray();

	static void Main()
	{
		try
		{
			sensor = KinectSensor.KinectSensors.FirstOrDefault(s => s.Status == KinectStatus.Connected);
			if (sensor == null)
			{
				Console.WriteLine("No Kinect v1 sensor detected (Status != Connected).");
				Console.WriteLine("Make sure Kinect is powered + USB connected, and SDK 1.8 is installed.");
				return;
			}

			// Streams
			sensor.SkeletonStream.Enable();
			sensor.DepthStream.Enable(DepthImageFormat.Resolution320x240Fps30);

			sensor.SkeletonFrameReady += SensorOnSkeletonFrameReady;

			sensor.Start();
			Console.WriteLine("Kinect started.");

			osc = new OscSender(IPAddress.Parse(OSC_IP), 0, OSC_PORT);
			osc.Connect();
			Console.WriteLine($"Sending OSC to {OSC_IP}:{OSC_PORT}");

			Console.WriteLine("Press ENTER to quit...");
			Console.ReadLine();
		}
		catch (Exception ex)
		{
			Console.WriteLine("Fatal error: " + ex.Message);
		}
		finally
		{
			try { if (osc != null) osc.Close(); } catch { }
			try { if (sensor != null) sensor.Stop(); } catch { }
		}
	}

	static void SensorOnSkeletonFrameReady(object sender, SkeletonFrameReadyEventArgs e)
	{
		if (sensor == null || osc == null) return;

		using (var frame = e.OpenSkeletonFrame())
		{
			if (frame == null) return;

			var skeletons = new Skeleton[frame.SkeletonArrayLength];
			frame.CopySkeletonDataTo(skeletons);

            var tracked = skeletons
                .Where(s => s != null && s.TrackingState == SkeletonTrackingState.Tracked)
                .ToList();

            // Status log (1 Hz): how many bodies are fully tracked vs position-only
            var now = DateTime.UtcNow;
            if ((now - lastStatusLog).TotalSeconds >= 1.0)
            {
                int trackedCount = skeletons.Count(s => s != null && s.TrackingState == SkeletonTrackingState.Tracked);
                int posOnlyCount = skeletons.Count(s => s != null && s.TrackingState == SkeletonTrackingState.PositionOnly);
                int notTrackedCount = skeletons.Count(s => s != null && s.TrackingState == SkeletonTrackingState.NotTracked);
                Console.WriteLine($"[Kinect] Tracked={trackedCount} PositionOnly={posOnlyCount} NotTracked={notTrackedCount}");
                lastStatusLog = now;
            }

            // Hand joint tracking log (1 Hz) for tracked bodies
            if ((now - lastHandLog).TotalSeconds >= 1.0)
            {
                foreach (var sk in tracked)
                {
                    var lh = sk.Joints[JointType.HandLeft].TrackingState;
                    var rh = sk.Joints[JointType.HandRight].TrackingState;
                    Console.WriteLine($"[Kinect] id={sk.TrackingId} LH={lh} RH={rh}");
                }
                lastHandLog = now;
            }

			// Update person slots (stable by TrackingId + miss tolerance)
			UpdatePersonSlots(tracked);

			// Build OSC payloads (fixed-length)
			var handsPayload = new float[MAX_HANDS * 4];   // [present, x, y, z] * 6
			var sizePayload = new float[MAX_HANDS];       // size per slot
			var energyPayload = new float[MAX_HANDS];       // arm energy per slot

			int dw = sensor.DepthStream.FrameWidth;
			int dh = sensor.DepthStream.FrameHeight;

			for (int p = 0; p < MAX_PEOPLE; p++)
			{
				var person = people[p];
				var sk = (person.TrackingId != 0)
					? tracked.FirstOrDefault(s => s.TrackingId == person.TrackingId)
					: null;

				// Left hand -> slot p*2, Right hand -> slot p*2+1
				ProcessHandSlot(sk, JointType.HandLeft, p * 2 + 0, dw, dh, handsPayload, sizePayload, energyPayload);
				ProcessHandSlot(sk, JointType.HandRight, p * 2 + 1, dw, dh, handsPayload, sizePayload, energyPayload);
			}

			// Send OSC: Rug.Osc takes object[]; convert floats to object[]
			osc.Send(new OscMessage("/hands", handsPayload.Cast<object>().ToArray()));
			osc.Send(new OscMessage("/hand_size", sizePayload.Cast<object>().ToArray()));
			osc.Send(new OscMessage("/arm_energy", energyPayload.Cast<object>().ToArray()));

			// Legacy /hand (first present slot)
			for (int slot = 0; slot < ACTIVE_HAND_SLOTS; slot++)
			{
				int baseIdx = slot * 4;
				if (handsPayload[baseIdx + 0] >= 0.5f)
				{
					osc.Send(new OscMessage("/hand", new object[] {
						handsPayload[baseIdx + 1],
						handsPayload[baseIdx + 2],
						handsPayload[baseIdx + 3]
					}));
					break;
				}
			}
		}
	}

	static void ProcessHandSlot(Skeleton sk, JointType handType, int slot, int dw, int dh,
								float[] handsPayload, float[] sizePayload, float[] energyPayload)
	{
		if (slot < 0 || slot >= ACTIVE_HAND_SLOTS || slot >= MAX_HANDS) return;
		int baseIdx = slot * 4;
		HandState st = handStates[slot];

		if (sk == null)
		{
			ClearSlot(baseIdx, slot, st, handsPayload, sizePayload, energyPayload);
			return;
		}

		Joint hand = GetBestHandJoint(sk, handType);
		if (hand.TrackingState == JointTrackingState.NotTracked)
		{
			ClearSlot(baseIdx, slot, st, handsPayload, sizePayload, energyPayload);
			return;
		}

		DepthImagePoint dp = sensor.CoordinateMapper.MapSkeletonPointToDepthPoint(
			hand.Position,
			sensor.DepthStream.Format
		);

		float xN = Clamp01(dp.X / (float)dw);
		float yN = Clamp01(dp.Y / (float)dh);

		if (FLIP_X) xN = 1.0f - xN;
		if (FLIP_Y) yN = 1.0f - yN;

		// Kinect v1 depth is mm (0 can appear sometimes); guard it
		float zM = (dp.Depth > 0) ? (dp.Depth / 1000.0f) : SCREEN_M;

		// proximity to screen plane: 0 when far in front, 1 at the screen
		float screenNearM = SCREEN_M - FRONT_RANGE_M;
		float p = Clamp01((zM - screenNearM) / FRONT_RANGE_M);

		// Processing expects z in [-0.2 .. 0.4] where near = -0.2, far = 0.4
		float zNorm = Lerp(0.4f, -0.2f, p);

		// size proxy: use proximity (works well with handNear)
		float size = p;

		// Arm energy: simple speed in normalized screen coords + depth
		float energyInstant = 0.0f;
		if (st.HasPrev)
		{
			float dx = xN - st.PrevXN;
			float dy = yN - st.PrevYN;
			float dz = zM - st.PrevZM;
			float speed = (float)Math.Sqrt(dx * dx + dy * dy + (dz * 0.35f) * (dz * 0.35f));
			energyInstant = speed * ARM_ENERGY_GAIN;
		}

		st.ArmEnergy = Lerp(st.ArmEnergy, energyInstant, ARM_ENERGY_SMOOTH);
		st.PrevXN = xN;
		st.PrevYN = yN;
		st.PrevZM = zM;
		st.HasPrev = true;

		handsPayload[baseIdx + 0] = 1.0f;
		handsPayload[baseIdx + 1] = xN;
		handsPayload[baseIdx + 2] = yN;
		handsPayload[baseIdx + 3] = zNorm;

		sizePayload[slot] = size;
		energyPayload[slot] = st.ArmEnergy;
	}

	static void ClearSlot(int baseIdx, int slot, HandState st,
						  float[] handsPayload, float[] sizePayload, float[] energyPayload)
	{
		handsPayload[baseIdx + 0] = 0.0f;
		handsPayload[baseIdx + 1] = 0.0f;
		handsPayload[baseIdx + 2] = 0.0f;
		handsPayload[baseIdx + 3] = 0.0f;
		sizePayload[slot] = 0.0f;
		energyPayload[slot] = 0.0f;

		st.ArmEnergy = Lerp(st.ArmEnergy, 0.0f, ARM_ENERGY_SMOOTH);
		st.HasPrev = false;
	}

	static void UpdatePersonSlots(List<Skeleton> tracked)
	{
		var presentIds = new HashSet<int>(tracked.Select(s => s.TrackingId));

		// 1) Keep existing slots if TrackingId still present, else count misses
		for (int i = 0; i < MAX_PEOPLE; i++)
		{
			var st = people[i];
			if (st.TrackingId == 0) continue;

			if (presentIds.Contains(st.TrackingId))
			{
				st.MissFrames = 0;
			}
			else
			{
				st.MissFrames++;
				if (st.MissFrames > SLOT_MISS_FORGET)
				{
					st.TrackingId = 0;
					st.MissFrames = 0;
				}
			}
		}

		// 2) Assign new tracked skeletons to empty slots
		foreach (var sk in tracked)
		{
			int tid = sk.TrackingId;
			bool alreadyAssigned = people.Any(s => s.TrackingId == tid);
			if (alreadyAssigned) continue;

			int empty = Array.FindIndex(people, s => s.TrackingId == 0);
			if (empty < 0) break;

			people[empty].TrackingId = tid;
			people[empty].MissFrames = 0;
		}
	}

	static Joint GetBestHandJoint(Skeleton sk, JointType handType)
	{
		// Prefer hand; if not tracked, fall back to wrist, then elbow.
		if (handType == JointType.HandLeft)
		{
			var hand = sk.Joints[JointType.HandLeft];
			if (hand.TrackingState != JointTrackingState.NotTracked) return hand;
			var wrist = sk.Joints[JointType.WristLeft];
			if (wrist.TrackingState != JointTrackingState.NotTracked) return wrist;
			var elbow = sk.Joints[JointType.ElbowLeft];
			if (elbow.TrackingState != JointTrackingState.NotTracked) return elbow;
			return hand;
		}
		else
		{
			var hand = sk.Joints[JointType.HandRight];
			if (hand.TrackingState != JointTrackingState.NotTracked) return hand;
			var wrist = sk.Joints[JointType.WristRight];
			if (wrist.TrackingState != JointTrackingState.NotTracked) return wrist;
			var elbow = sk.Joints[JointType.ElbowRight];
			if (elbow.TrackingState != JointTrackingState.NotTracked) return elbow;
			return hand;
		}
	}

	static float Clamp01(float v) => (v < 0) ? 0 : (v > 1) ? 1 : v;
	static float Lerp(float a, float b, float t) => a + (b - a) * t;
}
