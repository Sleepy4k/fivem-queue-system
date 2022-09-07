NKCore = {}

function NKCore.FormatString(data,...)
	return string.format(data,...)
end

function NKCore.SetPrint(data, ...)
	if data.title == nil then
		print('====================================================================')
	else
		print('============================ '..data.title..' ============================')
	end

	if data.message == nil then
		data.message = 'no data provided'
	else
		data.message = NKCore.FormatString(data.message,...)
	end
	
	if data.type == 'error' then
		if data.message ~= nil then
			print(('[^1ERROR^0] %s'):format(data.message))
		else
			print('[^1ERROR^0] No Info')
		end
	elseif data.type == 'warning' then
		if data.message ~= nil then
			print(('[^3WARNING^0] %s'):format(data.message))
		else
			print('[^3WARNING^0] No Info')
		end
	elseif data.type == 'success' then
		if data.message ~= nil then
			print(('[^2SUCCESS^0] %s'):format(data.message))
		else
			print('[^2SUCCESS^0] No Info')
		end
	elseif data.type == 'info' then
		if data.message ~= nil then
			print(('[^5INFO^0] %s'):format(data.message))
		else
			print('[^5INFO^0] No Info')
		end
	elseif data.type == 'custom' then
		if data.message ~= nil then
			print(('[^4%s^0] %s'):format(data.message))
		else
			print('[^4%s^0] No Info')
		end
	else
		if data.message ~= nil then
			print(('[^5INFO^0] %s'):format(data.message))
		else
			print('[^5INFO^0] No Info')
		end
	end
	
	print('====================================================================')
end