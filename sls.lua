local TERRAIN = game.Workspace.Terrain

local BEAM = Instance.new("Beam")
BEAM.Color = ColorSequence.new(Color3.new(1, 0, 0))
BEAM.Transparency = NumberSequence.new(0)
BEAM.FaceCamera = true
BEAM.Segments = 20
BEAM.Width0 = 0.1
BEAM.Width1 = 0.1

-- Class

local Trajectory = {}
Trajectory.__index = Trajectory

-- Private Functions

local function reflect(v, n)
	return -2*v:Dot(n)*n + v
end

local function drawBeamProjectile(g, v0, x0, t)
	local c = 0.5*0.5*0.5
	local p3 = 0.5*g*t*t + v0*t + x0
	local p2 = p3 - (g*t*t + v0*t)/3
	local p1 = (c*g*t*t + 0.5*v0*t + x0 - c*(x0+p3))/(3*c) - p2

	local curve0 = (p1 - x0).Magnitude
	local curve1 = (p2 - p3).Magnitude

	local b = (x0 - p3).unit
	local r1 = (p1 - x0).unit
	local u1 = r1:Cross(b).unit
	local r2 = (p2 - p3).unit
	local u2 = r2:Cross(b).unit
	b = u1:Cross(r1).unit

	local cfA = CFrame.fromMatrix(x0, r1, u1, b)
	local cfB = CFrame.fromMatrix(p3, r2, u2, b)

	local A0 = Instance.new("Attachment")
	local A1 = Instance.new("Attachment")
	local Beam = BEAM:Clone()

	A0.CFrame = cfA
	A0.Parent = TERRAIN
	A1.CFrame = cfB
	A1.Parent = TERRAIN

	Beam.Attachment0 = A0
	Beam.Attachment1 = A1
	Beam.CurveSize0 = curve0
	Beam.CurveSize1 = -curve1
	Beam.Parent = TERRAIN
end

-- Public Constructors
 
function Trajectory.new(gravity)
	local self = setmetatable({}, Trajectory)

	self.Gravity = gravity
	self.TimeStep = 0.1
	self.MaxTime = 5
	self.MinSpeed = 15
	self.MaxBounce = 5

	return self
end

-- Public Methods

function Trajectory:Velocity(v0, t)
	-- g*t + v0
	return self.Gravity*t + v0
end

function Trajectory:Position(x0, v0, t)
	-- 0.5*g*t^2 + v0*t + x0
	return 0.5*self.Gravity*t*t + v0*t + x0
end

function Trajectory:PlaneQuadraticIntersection(x0, v0, p, n)
	local a = (0.5*self.Gravity):Dot(n)
	local b = v0:Dot(n)
	local c = (x0 - p):Dot(n)

	if (a ~= 0) then
		local d = math.sqrt(b*b - 4*a*c)
		return (-b - d)/(2*a)
	else
		return -c / b
	end
end

function Trajectory:CalculateSingle(x0, v0, ignoreList)
	local t = 0
	local hit, pos, normal, material

	repeat
		local p0 = self:Position(x0, v0, t)
		local p1 = self:Position(x0, v0, t + self.TimeStep)
		t = t + self.TimeStep

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = ignoreList
        raycastParams.CollisionGroup = "Football"

        local direction = p1 - p0
        local result = workspace:Raycast(p0, direction, raycastParams)

        if result then
            hit = result.Instance
            pos = result.Position
            normal = result.Normal
            material = result.Material
        else
            hit, pos, normal, material = nil, nil, nil, nil
        end
	until (hit or t >= self.MaxTime)

	if (hit) then
		local t = self:PlaneQuadraticIntersection(x0, v0, pos, normal)
		local x1 = self:Position(x0, v0, t)
		return t, normal, hit.CurrentPhysicalProperties
	end
end

function Trajectory:Cast(x0, v0, object, ignoreList)
	local bounce = 0
	local t, x1, normal, pB
	local speed2 = self.MinSpeed*self.MinSpeed
	local pA = object.CurrentPhysicalProperties
	local path = {}
	local detailedPath = {}

	while (v0:Dot(v0) >= speed2 and bounce <= self.MaxBounce) do
		t, normal, pB = self:CalculateSingle(x0, v0, ignoreList)
		if (t) then
			table.insert(path, {x0, v0, t})

			local elast = (pA.Elasticity*pA.ElasticityWeight + pB.Elasticity*pB.ElasticityWeight)/(pA.ElasticityWeight+pB.ElasticityWeight)
			local frict = (pA.Friction*pA.FrictionWeight + pB.Friction*pB.FrictionWeight)/(pA.FrictionWeight+pB.FrictionWeight)
			local dot = 1 - math.abs(v0.Unit:Dot(normal))

            if frict ~= frict then
                frict = 1
            end

			x0 = self:Position(x0, v0, t)
			v0 = reflect(self:Velocity(v0, t), normal) * elast + v0 * frict * dot
			bounce = bounce + 1
		else
			bounce = self.MaxBounce + 1
		end
	end

	return path
end

function Trajectory:GetDetailedPath(path, pointsPerSegment)
	pointsPerSegment = pointsPerSegment or 10
	local detailedPoints = {}
	local cumulativeTime = 0
	
	for i = 1, #path do
		local x0, v0, t = unpack(path[i])
		
		for j = 0, pointsPerSegment do
			local segmentTime = t * (j / pointsPerSegment)
			local position = self:Position(x0, v0, segmentTime)
			local absoluteTime = cumulativeTime + segmentTime
			
			table.insert(detailedPoints, {
				position = position,
				time = absoluteTime,
				velocity = self:Velocity(v0, segmentTime)
			})
		end
		
		cumulativeTime = cumulativeTime + t
	end
	
	return detailedPoints
end

function Trajectory:Draw(path)
	for i = 1, #path do
		local x0, v0, t = unpack(path[i])
		drawBeamProjectile(self.Gravity, v0, x0, t)
	end
end
--

return Trajectory
