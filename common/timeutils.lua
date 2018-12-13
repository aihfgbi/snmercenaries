--
-- Author: Dengbing
-- Date: 2015-10-20 18:19:50
--

--将日期格式 2015-10-29 18:00:00 转换为时间戳
--返回 时间戳

timeutils = timeutils or {}


--2016-02-22T00:00:00
function timeutils.datestr_to_timestamp(str)
	local year,month,day,hour,min,sec = str:match("([^-]+)-([^-]+)-([^T]+)T([^:]+):([^:]+):([^:]+)")
	return os.time({year=year, month=month, day=day, hour=hour, min=min, sec=sec})
end
