package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
)

type Output struct {
	Step  int             `json:"step"`
	Name  string          `json:"name"`
	Multi bool            `json:"multi,omitempty"`
	Value json.RawMessage `json:"value"`
}

type OutputCacheEntry struct {
	Multi  bool
	Values []json.RawMessage
}

type ResolutionConfig struct {
	OutputCache map[string]map[int]map[string]OutputCacheEntry
}

func loadOutputFile(filename string) (map[int]map[string]OutputCacheEntry, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to open output file %s: %v", filename, err)
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	res := map[int]map[string]OutputCacheEntry{}
	for {
		var output Output
		if err := decoder.Decode(&output); err != nil {
			if err != io.EOF {
				return nil, fmt.Errorf("error decoding output from %s: %v", filename, err)
			}
			break
		}
		if _, has := res[output.Step]; !has {
			res[output.Step] = map[string]OutputCacheEntry{}
		}
		prev, has := res[output.Step][output.Name]
		if has {
			if output.Multi && prev.Multi {
				res[output.Step][output.Name] = OutputCacheEntry{Multi: true, Values: append(prev.Values, output.Value)}
			} else {
				return nil, fmt.Errorf("wrong output file %s: outputing multiple values for %s on step %d", filename, output.Name, output.Step)
			}
		} else {
			res[output.Step][output.Name] = OutputCacheEntry{Multi: output.Multi, Values: []json.RawMessage{output.Value}}
		}
	}
	return res, nil
}

type ComplexValue struct {
	Type string
	File string `json:",omitempty"`
	Step int
	Name string
}

func LocalComplexValue(step int, name string) ComplexValue {
	return ComplexValue{
		Type: "output",
		Step: step,
		Name: name,
	}
}

func ResolveParam(config ResolutionConfig, step int, raw json.RawMessage) (json.RawMessage, error) {
	var val ComplexValue
	if err := json.Unmarshal(raw, &val); err != nil {
		return raw, nil
	}
	if val.Type != "output" {
		return nil, fmt.Errorf("unknown type %s needed for step %d", val.Type, step)
	}
	if val.Step < 0 && val.File != "" {
		return nil, fmt.Errorf("use of negative step with file is prohibited, needed for step %d", step)
	}
	if _, has := config.OutputCache[val.File]; !has {
		fileEntry, err := loadOutputFile(val.File)
		if err != nil {
			return nil, fmt.Errorf("failed to read output file %s needed for step %d: %v", val.File, step, err)
		}
		config.OutputCache[val.File] = fileEntry
	}
	if val.Step < 0 {
		val.Step = val.Step + step
	}
	entry, has := config.OutputCache[val.File][val.Step][val.Name]
	if !has {
		return nil, fmt.Errorf("couldn't find output %s (step %d, file \"%s\") needed for step %d", val.Name, val.Step, val.File, step)
	}
	if entry.Multi {
		res, err := json.Marshal(entry.Values)
		if err != nil {
			return nil, fmt.Errorf("failed to marchal multivalue for output %s (step %d, file \"%s\") needed for step %d", val.Name, val.Step, val.File, step)
		}
		return res, nil
	} else {
		return entry.Values[0], nil
	}
}

func ResolveParams(config ResolutionConfig, step int, raw RawParams) (json.RawMessage, error) {
	for k, v := range raw {
		v_, err := ResolveParam(config, step, v)
		if err != nil {
			return nil, err
		}
		raw[k] = v_
	}
	return json.Marshal(raw)
}
