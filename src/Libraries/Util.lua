local Util = {}

--

function Util:SquareUniformRandomPosition(Size: Vector3)
    local Random = Random.new();
    
    return Vector3.new(
        Random:NextNumber(-Size.X / 2, Size.X / 2),
        Random:NextNumber(-Size.Y / 2, Size.Y / 2),
        Random:NextNumber(-Size.Z / 2, Size.Z / 2)
    )
end

function Util:GetNumberRangeValue(Range)
    local Random = Random.new();
    return Random:NextNumber(Range.Min, Range.Max)
end

function Util:Lerp(A, B, C)
    return A + (B - A) * C
end

function Util:GetNumberSequenceValue(Sequence: NumberSequence, Step: number)
	if Step == 0 then return Sequence.Keypoints[1].Value end
	if Step == 1 then return Sequence.Keypoints[#Sequence.Keypoints].Value end

	for i = 1, #Sequence.Keypoints - 1 do
		local Current = Sequence.Keypoints[i]
		local Next = Sequence.Keypoints[i + 1]

		if Step >= Current.Time and Step <= Next.Time then
			local Alpha = Step / Next.Time
			return self:Lerp(Current.Value, Next.Value, Alpha)
		end
	end
end

--

return Util