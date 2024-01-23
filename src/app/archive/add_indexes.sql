DROP INDEX IF EXISTS idx_zkapp_field_array_element_ids;
DROP INDEX IF EXISTS idx_zkapp_events_element_ids;

CREATE UNIQUE INDEX idx_zkapp_field_array_element_ids ON zkapp_field_array(element_ids);
CREATE UNIQUE INDEX idx_zkapp_events_element_ids ON zkapp_events(element_ids);
