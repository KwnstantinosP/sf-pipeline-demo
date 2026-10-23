trigger AccountTrigger on Account(before insert, before update) {
  CustomerSegmentService.assignSegments(Trigger.new, Trigger.oldMap);
}
