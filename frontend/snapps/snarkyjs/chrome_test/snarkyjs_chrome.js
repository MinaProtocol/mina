/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ "./src/bindings/snarky2.js":
/*!*********************************!*\
  !*** ./src/bindings/snarky2.js ***!
  \*********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Field": () => (/* binding */ Field),
/* harmony export */   "Bool": () => (/* binding */ Bool),
/* harmony export */   "Circuit": () => (/* binding */ Circuit),
/* harmony export */   "Poseidon": () => (/* binding */ Poseidon),
/* harmony export */   "Group": () => (/* binding */ Group),
/* harmony export */   "Scalar": () => (/* binding */ Scalar)
/* harmony export */ });
// if (window.__snarky) {
var Field = window.__snarky.Field;
var Bool = window.__snarky.Bool;
var Circuit = window.__snarky.Circuit;
var Poseidon = window.__snarky.Poseidon;
var Group = window.__snarky.Group;
var Scalar = window.__snarky.Scalar;
/*} else {
  import { Field as F, Bool as B, Circuit as C, Poseidon as P, Group as G, Scalar as S } from './snarky';
  export class Field = F;
  export class Bool = B;
  export class Circuit = C;
  export class Poseidon = P;
  export class Group = G;
  export class Scalar = S;
}
*/

/***/ }),

/***/ "./node_modules/reflect-metadata/Reflect.js":
/*!**************************************************!*\
  !*** ./node_modules/reflect-metadata/Reflect.js ***!
  \**************************************************/
/***/ (() => {

/*! *****************************************************************************
Copyright (C) Microsoft. All rights reserved.
Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at http://www.apache.org/licenses/LICENSE-2.0

THIS CODE IS PROVIDED ON AN *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
MERCHANTABLITY OR NON-INFRINGEMENT.

See the Apache Version 2.0 License for specific language governing permissions
and limitations under the License.
***************************************************************************** */
var Reflect;
(function (Reflect) {
    // Metadata Proposal
    // https://rbuckton.github.io/reflect-metadata/
    (function (factory) {
        var root = typeof global === "object" ? global :
            typeof self === "object" ? self :
                typeof this === "object" ? this :
                    Function("return this;")();
        var exporter = makeExporter(Reflect);
        if (typeof root.Reflect === "undefined") {
            root.Reflect = Reflect;
        }
        else {
            exporter = makeExporter(root.Reflect, exporter);
        }
        factory(exporter);
        function makeExporter(target, previous) {
            return function (key, value) {
                if (typeof target[key] !== "function") {
                    Object.defineProperty(target, key, { configurable: true, writable: true, value: value });
                }
                if (previous)
                    previous(key, value);
            };
        }
    })(function (exporter) {
        var hasOwn = Object.prototype.hasOwnProperty;
        // feature test for Symbol support
        var supportsSymbol = typeof Symbol === "function";
        var toPrimitiveSymbol = supportsSymbol && typeof Symbol.toPrimitive !== "undefined" ? Symbol.toPrimitive : "@@toPrimitive";
        var iteratorSymbol = supportsSymbol && typeof Symbol.iterator !== "undefined" ? Symbol.iterator : "@@iterator";
        var supportsCreate = typeof Object.create === "function"; // feature test for Object.create support
        var supportsProto = { __proto__: [] } instanceof Array; // feature test for __proto__ support
        var downLevel = !supportsCreate && !supportsProto;
        var HashMap = {
            // create an object in dictionary mode (a.k.a. "slow" mode in v8)
            create: supportsCreate
                ? function () { return MakeDictionary(Object.create(null)); }
                : supportsProto
                    ? function () { return MakeDictionary({ __proto__: null }); }
                    : function () { return MakeDictionary({}); },
            has: downLevel
                ? function (map, key) { return hasOwn.call(map, key); }
                : function (map, key) { return key in map; },
            get: downLevel
                ? function (map, key) { return hasOwn.call(map, key) ? map[key] : undefined; }
                : function (map, key) { return map[key]; },
        };
        // Load global or shim versions of Map, Set, and WeakMap
        var functionPrototype = Object.getPrototypeOf(Function);
        var usePolyfill = typeof process === "object" && process.env && process.env["REFLECT_METADATA_USE_MAP_POLYFILL"] === "true";
        var _Map = !usePolyfill && typeof Map === "function" && typeof Map.prototype.entries === "function" ? Map : CreateMapPolyfill();
        var _Set = !usePolyfill && typeof Set === "function" && typeof Set.prototype.entries === "function" ? Set : CreateSetPolyfill();
        var _WeakMap = !usePolyfill && typeof WeakMap === "function" ? WeakMap : CreateWeakMapPolyfill();
        // [[Metadata]] internal slot
        // https://rbuckton.github.io/reflect-metadata/#ordinary-object-internal-methods-and-internal-slots
        var Metadata = new _WeakMap();
        /**
         * Applies a set of decorators to a property of a target object.
         * @param decorators An array of decorators.
         * @param target The target object.
         * @param propertyKey (Optional) The property key to decorate.
         * @param attributes (Optional) The property descriptor for the target key.
         * @remarks Decorators are applied in reverse order.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     Example = Reflect.decorate(decoratorsArray, Example);
         *
         *     // property (on constructor)
         *     Reflect.decorate(decoratorsArray, Example, "staticProperty");
         *
         *     // property (on prototype)
         *     Reflect.decorate(decoratorsArray, Example.prototype, "property");
         *
         *     // method (on constructor)
         *     Object.defineProperty(Example, "staticMethod",
         *         Reflect.decorate(decoratorsArray, Example, "staticMethod",
         *             Object.getOwnPropertyDescriptor(Example, "staticMethod")));
         *
         *     // method (on prototype)
         *     Object.defineProperty(Example.prototype, "method",
         *         Reflect.decorate(decoratorsArray, Example.prototype, "method",
         *             Object.getOwnPropertyDescriptor(Example.prototype, "method")));
         *
         */
        function decorate(decorators, target, propertyKey, attributes) {
            if (!IsUndefined(propertyKey)) {
                if (!IsArray(decorators))
                    throw new TypeError();
                if (!IsObject(target))
                    throw new TypeError();
                if (!IsObject(attributes) && !IsUndefined(attributes) && !IsNull(attributes))
                    throw new TypeError();
                if (IsNull(attributes))
                    attributes = undefined;
                propertyKey = ToPropertyKey(propertyKey);
                return DecorateProperty(decorators, target, propertyKey, attributes);
            }
            else {
                if (!IsArray(decorators))
                    throw new TypeError();
                if (!IsConstructor(target))
                    throw new TypeError();
                return DecorateConstructor(decorators, target);
            }
        }
        exporter("decorate", decorate);
        // 4.1.2 Reflect.metadata(metadataKey, metadataValue)
        // https://rbuckton.github.io/reflect-metadata/#reflect.metadata
        /**
         * A default metadata decorator factory that can be used on a class, class member, or parameter.
         * @param metadataKey The key for the metadata entry.
         * @param metadataValue The value for the metadata entry.
         * @returns A decorator function.
         * @remarks
         * If `metadataKey` is already defined for the target and target key, the
         * metadataValue for that key will be overwritten.
         * @example
         *
         *     // constructor
         *     @Reflect.metadata(key, value)
         *     class Example {
         *     }
         *
         *     // property (on constructor, TypeScript only)
         *     class Example {
         *         @Reflect.metadata(key, value)
         *         static staticProperty;
         *     }
         *
         *     // property (on prototype, TypeScript only)
         *     class Example {
         *         @Reflect.metadata(key, value)
         *         property;
         *     }
         *
         *     // method (on constructor)
         *     class Example {
         *         @Reflect.metadata(key, value)
         *         static staticMethod() { }
         *     }
         *
         *     // method (on prototype)
         *     class Example {
         *         @Reflect.metadata(key, value)
         *         method() { }
         *     }
         *
         */
        function metadata(metadataKey, metadataValue) {
            function decorator(target, propertyKey) {
                if (!IsObject(target))
                    throw new TypeError();
                if (!IsUndefined(propertyKey) && !IsPropertyKey(propertyKey))
                    throw new TypeError();
                OrdinaryDefineOwnMetadata(metadataKey, metadataValue, target, propertyKey);
            }
            return decorator;
        }
        exporter("metadata", metadata);
        /**
         * Define a unique metadata entry on the target.
         * @param metadataKey A key used to store and retrieve metadata.
         * @param metadataValue A value that contains attached metadata.
         * @param target The target object on which to define metadata.
         * @param propertyKey (Optional) The property key for the target.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     Reflect.defineMetadata("custom:annotation", options, Example);
         *
         *     // property (on constructor)
         *     Reflect.defineMetadata("custom:annotation", options, Example, "staticProperty");
         *
         *     // property (on prototype)
         *     Reflect.defineMetadata("custom:annotation", options, Example.prototype, "property");
         *
         *     // method (on constructor)
         *     Reflect.defineMetadata("custom:annotation", options, Example, "staticMethod");
         *
         *     // method (on prototype)
         *     Reflect.defineMetadata("custom:annotation", options, Example.prototype, "method");
         *
         *     // decorator factory as metadata-producing annotation.
         *     function MyAnnotation(options): Decorator {
         *         return (target, key?) => Reflect.defineMetadata("custom:annotation", options, target, key);
         *     }
         *
         */
        function defineMetadata(metadataKey, metadataValue, target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryDefineOwnMetadata(metadataKey, metadataValue, target, propertyKey);
        }
        exporter("defineMetadata", defineMetadata);
        /**
         * Gets a value indicating whether the target object or its prototype chain has the provided metadata key defined.
         * @param metadataKey A key used to store and retrieve metadata.
         * @param target The target object on which the metadata is defined.
         * @param propertyKey (Optional) The property key for the target.
         * @returns `true` if the metadata key was defined on the target object or its prototype chain; otherwise, `false`.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     result = Reflect.hasMetadata("custom:annotation", Example);
         *
         *     // property (on constructor)
         *     result = Reflect.hasMetadata("custom:annotation", Example, "staticProperty");
         *
         *     // property (on prototype)
         *     result = Reflect.hasMetadata("custom:annotation", Example.prototype, "property");
         *
         *     // method (on constructor)
         *     result = Reflect.hasMetadata("custom:annotation", Example, "staticMethod");
         *
         *     // method (on prototype)
         *     result = Reflect.hasMetadata("custom:annotation", Example.prototype, "method");
         *
         */
        function hasMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryHasMetadata(metadataKey, target, propertyKey);
        }
        exporter("hasMetadata", hasMetadata);
        /**
         * Gets a value indicating whether the target object has the provided metadata key defined.
         * @param metadataKey A key used to store and retrieve metadata.
         * @param target The target object on which the metadata is defined.
         * @param propertyKey (Optional) The property key for the target.
         * @returns `true` if the metadata key was defined on the target object; otherwise, `false`.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     result = Reflect.hasOwnMetadata("custom:annotation", Example);
         *
         *     // property (on constructor)
         *     result = Reflect.hasOwnMetadata("custom:annotation", Example, "staticProperty");
         *
         *     // property (on prototype)
         *     result = Reflect.hasOwnMetadata("custom:annotation", Example.prototype, "property");
         *
         *     // method (on constructor)
         *     result = Reflect.hasOwnMetadata("custom:annotation", Example, "staticMethod");
         *
         *     // method (on prototype)
         *     result = Reflect.hasOwnMetadata("custom:annotation", Example.prototype, "method");
         *
         */
        function hasOwnMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryHasOwnMetadata(metadataKey, target, propertyKey);
        }
        exporter("hasOwnMetadata", hasOwnMetadata);
        /**
         * Gets the metadata value for the provided metadata key on the target object or its prototype chain.
         * @param metadataKey A key used to store and retrieve metadata.
         * @param target The target object on which the metadata is defined.
         * @param propertyKey (Optional) The property key for the target.
         * @returns The metadata value for the metadata key if found; otherwise, `undefined`.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     result = Reflect.getMetadata("custom:annotation", Example);
         *
         *     // property (on constructor)
         *     result = Reflect.getMetadata("custom:annotation", Example, "staticProperty");
         *
         *     // property (on prototype)
         *     result = Reflect.getMetadata("custom:annotation", Example.prototype, "property");
         *
         *     // method (on constructor)
         *     result = Reflect.getMetadata("custom:annotation", Example, "staticMethod");
         *
         *     // method (on prototype)
         *     result = Reflect.getMetadata("custom:annotation", Example.prototype, "method");
         *
         */
        function getMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryGetMetadata(metadataKey, target, propertyKey);
        }
        exporter("getMetadata", getMetadata);
        /**
         * Gets the metadata value for the provided metadata key on the target object.
         * @param metadataKey A key used to store and retrieve metadata.
         * @param target The target object on which the metadata is defined.
         * @param propertyKey (Optional) The property key for the target.
         * @returns The metadata value for the metadata key if found; otherwise, `undefined`.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     result = Reflect.getOwnMetadata("custom:annotation", Example);
         *
         *     // property (on constructor)
         *     result = Reflect.getOwnMetadata("custom:annotation", Example, "staticProperty");
         *
         *     // property (on prototype)
         *     result = Reflect.getOwnMetadata("custom:annotation", Example.prototype, "property");
         *
         *     // method (on constructor)
         *     result = Reflect.getOwnMetadata("custom:annotation", Example, "staticMethod");
         *
         *     // method (on prototype)
         *     result = Reflect.getOwnMetadata("custom:annotation", Example.prototype, "method");
         *
         */
        function getOwnMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryGetOwnMetadata(metadataKey, target, propertyKey);
        }
        exporter("getOwnMetadata", getOwnMetadata);
        /**
         * Gets the metadata keys defined on the target object or its prototype chain.
         * @param target The target object on which the metadata is defined.
         * @param propertyKey (Optional) The property key for the target.
         * @returns An array of unique metadata keys.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     result = Reflect.getMetadataKeys(Example);
         *
         *     // property (on constructor)
         *     result = Reflect.getMetadataKeys(Example, "staticProperty");
         *
         *     // property (on prototype)
         *     result = Reflect.getMetadataKeys(Example.prototype, "property");
         *
         *     // method (on constructor)
         *     result = Reflect.getMetadataKeys(Example, "staticMethod");
         *
         *     // method (on prototype)
         *     result = Reflect.getMetadataKeys(Example.prototype, "method");
         *
         */
        function getMetadataKeys(target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryMetadataKeys(target, propertyKey);
        }
        exporter("getMetadataKeys", getMetadataKeys);
        /**
         * Gets the unique metadata keys defined on the target object.
         * @param target The target object on which the metadata is defined.
         * @param propertyKey (Optional) The property key for the target.
         * @returns An array of unique metadata keys.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     result = Reflect.getOwnMetadataKeys(Example);
         *
         *     // property (on constructor)
         *     result = Reflect.getOwnMetadataKeys(Example, "staticProperty");
         *
         *     // property (on prototype)
         *     result = Reflect.getOwnMetadataKeys(Example.prototype, "property");
         *
         *     // method (on constructor)
         *     result = Reflect.getOwnMetadataKeys(Example, "staticMethod");
         *
         *     // method (on prototype)
         *     result = Reflect.getOwnMetadataKeys(Example.prototype, "method");
         *
         */
        function getOwnMetadataKeys(target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryOwnMetadataKeys(target, propertyKey);
        }
        exporter("getOwnMetadataKeys", getOwnMetadataKeys);
        /**
         * Deletes the metadata entry from the target object with the provided key.
         * @param metadataKey A key used to store and retrieve metadata.
         * @param target The target object on which the metadata is defined.
         * @param propertyKey (Optional) The property key for the target.
         * @returns `true` if the metadata entry was found and deleted; otherwise, false.
         * @example
         *
         *     class Example {
         *         // property declarations are not part of ES6, though they are valid in TypeScript:
         *         // static staticProperty;
         *         // property;
         *
         *         constructor(p) { }
         *         static staticMethod(p) { }
         *         method(p) { }
         *     }
         *
         *     // constructor
         *     result = Reflect.deleteMetadata("custom:annotation", Example);
         *
         *     // property (on constructor)
         *     result = Reflect.deleteMetadata("custom:annotation", Example, "staticProperty");
         *
         *     // property (on prototype)
         *     result = Reflect.deleteMetadata("custom:annotation", Example.prototype, "property");
         *
         *     // method (on constructor)
         *     result = Reflect.deleteMetadata("custom:annotation", Example, "staticMethod");
         *
         *     // method (on prototype)
         *     result = Reflect.deleteMetadata("custom:annotation", Example.prototype, "method");
         *
         */
        function deleteMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
                throw new TypeError();
            if (!IsUndefined(propertyKey))
                propertyKey = ToPropertyKey(propertyKey);
            var metadataMap = GetOrCreateMetadataMap(target, propertyKey, /*Create*/ false);
            if (IsUndefined(metadataMap))
                return false;
            if (!metadataMap.delete(metadataKey))
                return false;
            if (metadataMap.size > 0)
                return true;
            var targetMetadata = Metadata.get(target);
            targetMetadata.delete(propertyKey);
            if (targetMetadata.size > 0)
                return true;
            Metadata.delete(target);
            return true;
        }
        exporter("deleteMetadata", deleteMetadata);
        function DecorateConstructor(decorators, target) {
            for (var i = decorators.length - 1; i >= 0; --i) {
                var decorator = decorators[i];
                var decorated = decorator(target);
                if (!IsUndefined(decorated) && !IsNull(decorated)) {
                    if (!IsConstructor(decorated))
                        throw new TypeError();
                    target = decorated;
                }
            }
            return target;
        }
        function DecorateProperty(decorators, target, propertyKey, descriptor) {
            for (var i = decorators.length - 1; i >= 0; --i) {
                var decorator = decorators[i];
                var decorated = decorator(target, propertyKey, descriptor);
                if (!IsUndefined(decorated) && !IsNull(decorated)) {
                    if (!IsObject(decorated))
                        throw new TypeError();
                    descriptor = decorated;
                }
            }
            return descriptor;
        }
        function GetOrCreateMetadataMap(O, P, Create) {
            var targetMetadata = Metadata.get(O);
            if (IsUndefined(targetMetadata)) {
                if (!Create)
                    return undefined;
                targetMetadata = new _Map();
                Metadata.set(O, targetMetadata);
            }
            var metadataMap = targetMetadata.get(P);
            if (IsUndefined(metadataMap)) {
                if (!Create)
                    return undefined;
                metadataMap = new _Map();
                targetMetadata.set(P, metadataMap);
            }
            return metadataMap;
        }
        // 3.1.1.1 OrdinaryHasMetadata(MetadataKey, O, P)
        // https://rbuckton.github.io/reflect-metadata/#ordinaryhasmetadata
        function OrdinaryHasMetadata(MetadataKey, O, P) {
            var hasOwn = OrdinaryHasOwnMetadata(MetadataKey, O, P);
            if (hasOwn)
                return true;
            var parent = OrdinaryGetPrototypeOf(O);
            if (!IsNull(parent))
                return OrdinaryHasMetadata(MetadataKey, parent, P);
            return false;
        }
        // 3.1.2.1 OrdinaryHasOwnMetadata(MetadataKey, O, P)
        // https://rbuckton.github.io/reflect-metadata/#ordinaryhasownmetadata
        function OrdinaryHasOwnMetadata(MetadataKey, O, P) {
            var metadataMap = GetOrCreateMetadataMap(O, P, /*Create*/ false);
            if (IsUndefined(metadataMap))
                return false;
            return ToBoolean(metadataMap.has(MetadataKey));
        }
        // 3.1.3.1 OrdinaryGetMetadata(MetadataKey, O, P)
        // https://rbuckton.github.io/reflect-metadata/#ordinarygetmetadata
        function OrdinaryGetMetadata(MetadataKey, O, P) {
            var hasOwn = OrdinaryHasOwnMetadata(MetadataKey, O, P);
            if (hasOwn)
                return OrdinaryGetOwnMetadata(MetadataKey, O, P);
            var parent = OrdinaryGetPrototypeOf(O);
            if (!IsNull(parent))
                return OrdinaryGetMetadata(MetadataKey, parent, P);
            return undefined;
        }
        // 3.1.4.1 OrdinaryGetOwnMetadata(MetadataKey, O, P)
        // https://rbuckton.github.io/reflect-metadata/#ordinarygetownmetadata
        function OrdinaryGetOwnMetadata(MetadataKey, O, P) {
            var metadataMap = GetOrCreateMetadataMap(O, P, /*Create*/ false);
            if (IsUndefined(metadataMap))
                return undefined;
            return metadataMap.get(MetadataKey);
        }
        // 3.1.5.1 OrdinaryDefineOwnMetadata(MetadataKey, MetadataValue, O, P)
        // https://rbuckton.github.io/reflect-metadata/#ordinarydefineownmetadata
        function OrdinaryDefineOwnMetadata(MetadataKey, MetadataValue, O, P) {
            var metadataMap = GetOrCreateMetadataMap(O, P, /*Create*/ true);
            metadataMap.set(MetadataKey, MetadataValue);
        }
        // 3.1.6.1 OrdinaryMetadataKeys(O, P)
        // https://rbuckton.github.io/reflect-metadata/#ordinarymetadatakeys
        function OrdinaryMetadataKeys(O, P) {
            var ownKeys = OrdinaryOwnMetadataKeys(O, P);
            var parent = OrdinaryGetPrototypeOf(O);
            if (parent === null)
                return ownKeys;
            var parentKeys = OrdinaryMetadataKeys(parent, P);
            if (parentKeys.length <= 0)
                return ownKeys;
            if (ownKeys.length <= 0)
                return parentKeys;
            var set = new _Set();
            var keys = [];
            for (var _i = 0, ownKeys_1 = ownKeys; _i < ownKeys_1.length; _i++) {
                var key = ownKeys_1[_i];
                var hasKey = set.has(key);
                if (!hasKey) {
                    set.add(key);
                    keys.push(key);
                }
            }
            for (var _a = 0, parentKeys_1 = parentKeys; _a < parentKeys_1.length; _a++) {
                var key = parentKeys_1[_a];
                var hasKey = set.has(key);
                if (!hasKey) {
                    set.add(key);
                    keys.push(key);
                }
            }
            return keys;
        }
        // 3.1.7.1 OrdinaryOwnMetadataKeys(O, P)
        // https://rbuckton.github.io/reflect-metadata/#ordinaryownmetadatakeys
        function OrdinaryOwnMetadataKeys(O, P) {
            var keys = [];
            var metadataMap = GetOrCreateMetadataMap(O, P, /*Create*/ false);
            if (IsUndefined(metadataMap))
                return keys;
            var keysObj = metadataMap.keys();
            var iterator = GetIterator(keysObj);
            var k = 0;
            while (true) {
                var next = IteratorStep(iterator);
                if (!next) {
                    keys.length = k;
                    return keys;
                }
                var nextValue = IteratorValue(next);
                try {
                    keys[k] = nextValue;
                }
                catch (e) {
                    try {
                        IteratorClose(iterator);
                    }
                    finally {
                        throw e;
                    }
                }
                k++;
            }
        }
        // 6 ECMAScript Data Typ0es and Values
        // https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values
        function Type(x) {
            if (x === null)
                return 1 /* Null */;
            switch (typeof x) {
                case "undefined": return 0 /* Undefined */;
                case "boolean": return 2 /* Boolean */;
                case "string": return 3 /* String */;
                case "symbol": return 4 /* Symbol */;
                case "number": return 5 /* Number */;
                case "object": return x === null ? 1 /* Null */ : 6 /* Object */;
                default: return 6 /* Object */;
            }
        }
        // 6.1.1 The Undefined Type
        // https://tc39.github.io/ecma262/#sec-ecmascript-language-types-undefined-type
        function IsUndefined(x) {
            return x === undefined;
        }
        // 6.1.2 The Null Type
        // https://tc39.github.io/ecma262/#sec-ecmascript-language-types-null-type
        function IsNull(x) {
            return x === null;
        }
        // 6.1.5 The Symbol Type
        // https://tc39.github.io/ecma262/#sec-ecmascript-language-types-symbol-type
        function IsSymbol(x) {
            return typeof x === "symbol";
        }
        // 6.1.7 The Object Type
        // https://tc39.github.io/ecma262/#sec-object-type
        function IsObject(x) {
            return typeof x === "object" ? x !== null : typeof x === "function";
        }
        // 7.1 Type Conversion
        // https://tc39.github.io/ecma262/#sec-type-conversion
        // 7.1.1 ToPrimitive(input [, PreferredType])
        // https://tc39.github.io/ecma262/#sec-toprimitive
        function ToPrimitive(input, PreferredType) {
            switch (Type(input)) {
                case 0 /* Undefined */: return input;
                case 1 /* Null */: return input;
                case 2 /* Boolean */: return input;
                case 3 /* String */: return input;
                case 4 /* Symbol */: return input;
                case 5 /* Number */: return input;
            }
            var hint = PreferredType === 3 /* String */ ? "string" : PreferredType === 5 /* Number */ ? "number" : "default";
            var exoticToPrim = GetMethod(input, toPrimitiveSymbol);
            if (exoticToPrim !== undefined) {
                var result = exoticToPrim.call(input, hint);
                if (IsObject(result))
                    throw new TypeError();
                return result;
            }
            return OrdinaryToPrimitive(input, hint === "default" ? "number" : hint);
        }
        // 7.1.1.1 OrdinaryToPrimitive(O, hint)
        // https://tc39.github.io/ecma262/#sec-ordinarytoprimitive
        function OrdinaryToPrimitive(O, hint) {
            if (hint === "string") {
                var toString_1 = O.toString;
                if (IsCallable(toString_1)) {
                    var result = toString_1.call(O);
                    if (!IsObject(result))
                        return result;
                }
                var valueOf = O.valueOf;
                if (IsCallable(valueOf)) {
                    var result = valueOf.call(O);
                    if (!IsObject(result))
                        return result;
                }
            }
            else {
                var valueOf = O.valueOf;
                if (IsCallable(valueOf)) {
                    var result = valueOf.call(O);
                    if (!IsObject(result))
                        return result;
                }
                var toString_2 = O.toString;
                if (IsCallable(toString_2)) {
                    var result = toString_2.call(O);
                    if (!IsObject(result))
                        return result;
                }
            }
            throw new TypeError();
        }
        // 7.1.2 ToBoolean(argument)
        // https://tc39.github.io/ecma262/2016/#sec-toboolean
        function ToBoolean(argument) {
            return !!argument;
        }
        // 7.1.12 ToString(argument)
        // https://tc39.github.io/ecma262/#sec-tostring
        function ToString(argument) {
            return "" + argument;
        }
        // 7.1.14 ToPropertyKey(argument)
        // https://tc39.github.io/ecma262/#sec-topropertykey
        function ToPropertyKey(argument) {
            var key = ToPrimitive(argument, 3 /* String */);
            if (IsSymbol(key))
                return key;
            return ToString(key);
        }
        // 7.2 Testing and Comparison Operations
        // https://tc39.github.io/ecma262/#sec-testing-and-comparison-operations
        // 7.2.2 IsArray(argument)
        // https://tc39.github.io/ecma262/#sec-isarray
        function IsArray(argument) {
            return Array.isArray
                ? Array.isArray(argument)
                : argument instanceof Object
                    ? argument instanceof Array
                    : Object.prototype.toString.call(argument) === "[object Array]";
        }
        // 7.2.3 IsCallable(argument)
        // https://tc39.github.io/ecma262/#sec-iscallable
        function IsCallable(argument) {
            // NOTE: This is an approximation as we cannot check for [[Call]] internal method.
            return typeof argument === "function";
        }
        // 7.2.4 IsConstructor(argument)
        // https://tc39.github.io/ecma262/#sec-isconstructor
        function IsConstructor(argument) {
            // NOTE: This is an approximation as we cannot check for [[Construct]] internal method.
            return typeof argument === "function";
        }
        // 7.2.7 IsPropertyKey(argument)
        // https://tc39.github.io/ecma262/#sec-ispropertykey
        function IsPropertyKey(argument) {
            switch (Type(argument)) {
                case 3 /* String */: return true;
                case 4 /* Symbol */: return true;
                default: return false;
            }
        }
        // 7.3 Operations on Objects
        // https://tc39.github.io/ecma262/#sec-operations-on-objects
        // 7.3.9 GetMethod(V, P)
        // https://tc39.github.io/ecma262/#sec-getmethod
        function GetMethod(V, P) {
            var func = V[P];
            if (func === undefined || func === null)
                return undefined;
            if (!IsCallable(func))
                throw new TypeError();
            return func;
        }
        // 7.4 Operations on Iterator Objects
        // https://tc39.github.io/ecma262/#sec-operations-on-iterator-objects
        function GetIterator(obj) {
            var method = GetMethod(obj, iteratorSymbol);
            if (!IsCallable(method))
                throw new TypeError(); // from Call
            var iterator = method.call(obj);
            if (!IsObject(iterator))
                throw new TypeError();
            return iterator;
        }
        // 7.4.4 IteratorValue(iterResult)
        // https://tc39.github.io/ecma262/2016/#sec-iteratorvalue
        function IteratorValue(iterResult) {
            return iterResult.value;
        }
        // 7.4.5 IteratorStep(iterator)
        // https://tc39.github.io/ecma262/#sec-iteratorstep
        function IteratorStep(iterator) {
            var result = iterator.next();
            return result.done ? false : result;
        }
        // 7.4.6 IteratorClose(iterator, completion)
        // https://tc39.github.io/ecma262/#sec-iteratorclose
        function IteratorClose(iterator) {
            var f = iterator["return"];
            if (f)
                f.call(iterator);
        }
        // 9.1 Ordinary Object Internal Methods and Internal Slots
        // https://tc39.github.io/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots
        // 9.1.1.1 OrdinaryGetPrototypeOf(O)
        // https://tc39.github.io/ecma262/#sec-ordinarygetprototypeof
        function OrdinaryGetPrototypeOf(O) {
            var proto = Object.getPrototypeOf(O);
            if (typeof O !== "function" || O === functionPrototype)
                return proto;
            // TypeScript doesn't set __proto__ in ES5, as it's non-standard.
            // Try to determine the superclass constructor. Compatible implementations
            // must either set __proto__ on a subclass constructor to the superclass constructor,
            // or ensure each class has a valid `constructor` property on its prototype that
            // points back to the constructor.
            // If this is not the same as Function.[[Prototype]], then this is definately inherited.
            // This is the case when in ES6 or when using __proto__ in a compatible browser.
            if (proto !== functionPrototype)
                return proto;
            // If the super prototype is Object.prototype, null, or undefined, then we cannot determine the heritage.
            var prototype = O.prototype;
            var prototypeProto = prototype && Object.getPrototypeOf(prototype);
            if (prototypeProto == null || prototypeProto === Object.prototype)
                return proto;
            // If the constructor was not a function, then we cannot determine the heritage.
            var constructor = prototypeProto.constructor;
            if (typeof constructor !== "function")
                return proto;
            // If we have some kind of self-reference, then we cannot determine the heritage.
            if (constructor === O)
                return proto;
            // we have a pretty good guess at the heritage.
            return constructor;
        }
        // naive Map shim
        function CreateMapPolyfill() {
            var cacheSentinel = {};
            var arraySentinel = [];
            var MapIterator = /** @class */ (function () {
                function MapIterator(keys, values, selector) {
                    this._index = 0;
                    this._keys = keys;
                    this._values = values;
                    this._selector = selector;
                }
                MapIterator.prototype["@@iterator"] = function () { return this; };
                MapIterator.prototype[iteratorSymbol] = function () { return this; };
                MapIterator.prototype.next = function () {
                    var index = this._index;
                    if (index >= 0 && index < this._keys.length) {
                        var result = this._selector(this._keys[index], this._values[index]);
                        if (index + 1 >= this._keys.length) {
                            this._index = -1;
                            this._keys = arraySentinel;
                            this._values = arraySentinel;
                        }
                        else {
                            this._index++;
                        }
                        return { value: result, done: false };
                    }
                    return { value: undefined, done: true };
                };
                MapIterator.prototype.throw = function (error) {
                    if (this._index >= 0) {
                        this._index = -1;
                        this._keys = arraySentinel;
                        this._values = arraySentinel;
                    }
                    throw error;
                };
                MapIterator.prototype.return = function (value) {
                    if (this._index >= 0) {
                        this._index = -1;
                        this._keys = arraySentinel;
                        this._values = arraySentinel;
                    }
                    return { value: value, done: true };
                };
                return MapIterator;
            }());
            return /** @class */ (function () {
                function Map() {
                    this._keys = [];
                    this._values = [];
                    this._cacheKey = cacheSentinel;
                    this._cacheIndex = -2;
                }
                Object.defineProperty(Map.prototype, "size", {
                    get: function () { return this._keys.length; },
                    enumerable: true,
                    configurable: true
                });
                Map.prototype.has = function (key) { return this._find(key, /*insert*/ false) >= 0; };
                Map.prototype.get = function (key) {
                    var index = this._find(key, /*insert*/ false);
                    return index >= 0 ? this._values[index] : undefined;
                };
                Map.prototype.set = function (key, value) {
                    var index = this._find(key, /*insert*/ true);
                    this._values[index] = value;
                    return this;
                };
                Map.prototype.delete = function (key) {
                    var index = this._find(key, /*insert*/ false);
                    if (index >= 0) {
                        var size = this._keys.length;
                        for (var i = index + 1; i < size; i++) {
                            this._keys[i - 1] = this._keys[i];
                            this._values[i - 1] = this._values[i];
                        }
                        this._keys.length--;
                        this._values.length--;
                        if (key === this._cacheKey) {
                            this._cacheKey = cacheSentinel;
                            this._cacheIndex = -2;
                        }
                        return true;
                    }
                    return false;
                };
                Map.prototype.clear = function () {
                    this._keys.length = 0;
                    this._values.length = 0;
                    this._cacheKey = cacheSentinel;
                    this._cacheIndex = -2;
                };
                Map.prototype.keys = function () { return new MapIterator(this._keys, this._values, getKey); };
                Map.prototype.values = function () { return new MapIterator(this._keys, this._values, getValue); };
                Map.prototype.entries = function () { return new MapIterator(this._keys, this._values, getEntry); };
                Map.prototype["@@iterator"] = function () { return this.entries(); };
                Map.prototype[iteratorSymbol] = function () { return this.entries(); };
                Map.prototype._find = function (key, insert) {
                    if (this._cacheKey !== key) {
                        this._cacheIndex = this._keys.indexOf(this._cacheKey = key);
                    }
                    if (this._cacheIndex < 0 && insert) {
                        this._cacheIndex = this._keys.length;
                        this._keys.push(key);
                        this._values.push(undefined);
                    }
                    return this._cacheIndex;
                };
                return Map;
            }());
            function getKey(key, _) {
                return key;
            }
            function getValue(_, value) {
                return value;
            }
            function getEntry(key, value) {
                return [key, value];
            }
        }
        // naive Set shim
        function CreateSetPolyfill() {
            return /** @class */ (function () {
                function Set() {
                    this._map = new _Map();
                }
                Object.defineProperty(Set.prototype, "size", {
                    get: function () { return this._map.size; },
                    enumerable: true,
                    configurable: true
                });
                Set.prototype.has = function (value) { return this._map.has(value); };
                Set.prototype.add = function (value) { return this._map.set(value, value), this; };
                Set.prototype.delete = function (value) { return this._map.delete(value); };
                Set.prototype.clear = function () { this._map.clear(); };
                Set.prototype.keys = function () { return this._map.keys(); };
                Set.prototype.values = function () { return this._map.values(); };
                Set.prototype.entries = function () { return this._map.entries(); };
                Set.prototype["@@iterator"] = function () { return this.keys(); };
                Set.prototype[iteratorSymbol] = function () { return this.keys(); };
                return Set;
            }());
        }
        // naive WeakMap shim
        function CreateWeakMapPolyfill() {
            var UUID_SIZE = 16;
            var keys = HashMap.create();
            var rootKey = CreateUniqueKey();
            return /** @class */ (function () {
                function WeakMap() {
                    this._key = CreateUniqueKey();
                }
                WeakMap.prototype.has = function (target) {
                    var table = GetOrCreateWeakMapTable(target, /*create*/ false);
                    return table !== undefined ? HashMap.has(table, this._key) : false;
                };
                WeakMap.prototype.get = function (target) {
                    var table = GetOrCreateWeakMapTable(target, /*create*/ false);
                    return table !== undefined ? HashMap.get(table, this._key) : undefined;
                };
                WeakMap.prototype.set = function (target, value) {
                    var table = GetOrCreateWeakMapTable(target, /*create*/ true);
                    table[this._key] = value;
                    return this;
                };
                WeakMap.prototype.delete = function (target) {
                    var table = GetOrCreateWeakMapTable(target, /*create*/ false);
                    return table !== undefined ? delete table[this._key] : false;
                };
                WeakMap.prototype.clear = function () {
                    // NOTE: not a real clear, just makes the previous data unreachable
                    this._key = CreateUniqueKey();
                };
                return WeakMap;
            }());
            function CreateUniqueKey() {
                var key;
                do
                    key = "@@WeakMap@@" + CreateUUID();
                while (HashMap.has(keys, key));
                keys[key] = true;
                return key;
            }
            function GetOrCreateWeakMapTable(target, create) {
                if (!hasOwn.call(target, rootKey)) {
                    if (!create)
                        return undefined;
                    Object.defineProperty(target, rootKey, { value: HashMap.create() });
                }
                return target[rootKey];
            }
            function FillRandomBytes(buffer, size) {
                for (var i = 0; i < size; ++i)
                    buffer[i] = Math.random() * 0xff | 0;
                return buffer;
            }
            function GenRandomBytes(size) {
                if (typeof Uint8Array === "function") {
                    if (typeof crypto !== "undefined")
                        return crypto.getRandomValues(new Uint8Array(size));
                    if (typeof msCrypto !== "undefined")
                        return msCrypto.getRandomValues(new Uint8Array(size));
                    return FillRandomBytes(new Uint8Array(size), size);
                }
                return FillRandomBytes(new Array(size), size);
            }
            function CreateUUID() {
                var data = GenRandomBytes(UUID_SIZE);
                // mark as random - RFC 4122 § 4.4
                data[6] = data[6] & 0x4f | 0x40;
                data[8] = data[8] & 0xbf | 0x80;
                var result = "";
                for (var offset = 0; offset < UUID_SIZE; ++offset) {
                    var byte = data[offset];
                    if (offset === 4 || offset === 6 || offset === 8)
                        result += "-";
                    if (byte < 16)
                        result += "0";
                    result += byte.toString(16).toLowerCase();
                }
                return result;
            }
        }
        // uses a heuristic used by v8 and chakra to force an object into dictionary mode.
        function MakeDictionary(obj) {
            obj.__ = undefined;
            delete obj.__;
            return obj;
        }
    });
})(Reflect || (Reflect = {}));


/***/ }),

/***/ "./src/circuit_value.ts":
/*!******************************!*\
  !*** ./src/circuit_value.ts ***!
  \******************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "CircuitValue": () => (/* binding */ CircuitValue),
/* harmony export */   "prop": () => (/* binding */ prop),
/* harmony export */   "public_": () => (/* binding */ public_),
/* harmony export */   "circuitMain": () => (/* binding */ circuitMain)
/* harmony export */ });
/* harmony import */ var reflect_metadata__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! reflect-metadata */ "./node_modules/reflect-metadata/Reflect.js");
/* harmony import */ var reflect_metadata__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(reflect_metadata__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var _bindings_snarky2__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./bindings/snarky2 */ "./src/bindings/snarky2.js");


class CircuitValue {
    static sizeInFieldElements() {
        const fields = this.prototype._fields;
        return fields.reduce((acc, [_, typ]) => acc + typ.sizeInFieldElements(), 0);
    }
    static toFieldElements(v) {
        const res = [];
        const fields = this.prototype._fields;
        if (fields === undefined || fields === null) {
            return res;
        }
        for (let i = 0; i < fields.length; ++i) {
            const [key, propType] = fields[i];
            const subElts = propType.toFieldElements(v[key]);
            subElts.forEach((x) => res.push(x));
        }
        return res;
    }
    toFieldElements() {
        return this.constructor.toFieldElements(this);
    }
    equals(x) {
        return _bindings_snarky2__WEBPACK_IMPORTED_MODULE_1__.Circuit.equal(this, x);
    }
    assertEquals(x) {
        _bindings_snarky2__WEBPACK_IMPORTED_MODULE_1__.Circuit.assertEqual(this, x);
    }
    static ofFieldElements(xs) {
        const fields = this.prototype._fields;
        let offset = 0;
        const props = [];
        for (let i = 0; i < fields.length; ++i) {
            const propType = fields[i][1];
            const propSize = propType.sizeInFieldElements();
            const propVal = propType.ofFieldElements(xs.slice(offset, offset + propSize));
            props.push(propVal);
            offset += propSize;
        }
        return new this(...props);
    }
    static toJSON(v) {
        const res = {};
        if (this.prototype._fields !== undefined) {
            const fields = this.prototype._fields;
            fields.forEach(([key, propType]) => {
                res[key] = propType.toJSON(v[key]);
            });
        }
        return res;
    }
    static fromJSON(value) {
        const props = [];
        const fields = this.prototype._fields;
        switch (typeof value) {
            case 'object':
                if (value === null || Array.isArray(value)) {
                    return null;
                }
                break;
            default:
                return null;
        }
        if (fields !== undefined) {
            for (let i = 0; i < fields.length; ++i) {
                const [key, propType] = fields[i];
                if (value[key] === undefined) {
                    return null;
                }
                else {
                    props.push(propType.fromJSON(value[key]));
                }
            }
        }
        return new this(...props);
    }
}
function prop(target, key) {
    const fieldType = Reflect.getMetadata('design:type', target, key);
    if (target._fields === undefined || target._fields === null) {
        target._fields = [];
    }
    if (fieldType === undefined) {
    }
    else if (fieldType.toFieldElements && fieldType.ofFieldElements) {
        target._fields.push([key, fieldType]);
    }
    else {
        console.log(`warning: property ${key} missing field element conversion methods`);
    }
}
function public_(target, _key, index) {
    // const fieldType = Reflect.getMetadata('design:paramtypes', target, key);
    if (target._public === undefined) {
        target._public = [];
    }
    target._public.push(index);
}
function typOfArray(typs) {
    return {
        sizeInFieldElements: () => {
            return typs.reduce((acc, typ) => acc + typ.sizeInFieldElements(), 0);
        },
        toFieldElements: (t) => {
            let res = [];
            for (let i = 0; i < t.length; ++i) {
                res.push(...typs[i].toFieldElements(t[i]));
            }
            return res;
        },
        ofFieldElements: (xs) => {
            let offset = 0;
            let res = [];
            typs.forEach((typ) => {
                const n = typ.sizeInFieldElements();
                res.push(typ.ofFieldElements(xs.slice(offset, offset + n)));
                offset += n;
            });
            return res;
        },
    };
}
function circuitMain(target, propertyName, _descriptor) {
    const paramTypes = Reflect.getMetadata('design:paramtypes', target, propertyName);
    const numArgs = paramTypes.length;
    const publicIndexSet = new Set(target._public);
    const witnessIndexSet = new Set();
    for (let i = 0; i < numArgs; ++i) {
        if (!publicIndexSet.has(i)) {
            witnessIndexSet.add(i);
        }
    }
    target.snarkyMain = (w, pub) => {
        let args = [];
        for (let i = 0; i < numArgs; ++i) {
            args.push((publicIndexSet.has(i) ? pub : w).shift());
        }
        return target[propertyName].apply(target, args);
    };
    target.snarkyWitnessTyp = typOfArray(Array.from(witnessIndexSet).map((i) => paramTypes[i]));
    target.snarkyPublicTyp = typOfArray(Array.from(publicIndexSet).map((i) => paramTypes[i]));
}


/***/ }),

/***/ "./src/examples/exchange.ts":
/*!**********************************!*\
  !*** ./src/examples/exchange.ts ***!
  \**********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Main": () => (/* binding */ Main),
/* harmony export */   "main": () => (/* binding */ main)
/* harmony export */ });
/* harmony import */ var tslib__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! tslib */ "./node_modules/tslib/tslib.es6.js");
/* harmony import */ var _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../bindings/snarky2 */ "./src/bindings/snarky2.js");
/* harmony import */ var _circuit_value__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../circuit_value */ "./src/circuit_value.ts");
/* harmony import */ var _exchange_lib__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./exchange_lib */ "./src/examples/exchange_lib.ts");
/* harmony import */ var _signature__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../signature */ "./src/signature.ts");

// import { MerkleCollection, MerkleProof } from '../mina.js';




// Proof of bought low sold high for bragging rights
// 
// Prove I did a trade that did "X%" increase
class Witness extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    pairIndex;
    attestation;
    constructor(pairIndex, a) {
        super();
        this.pairIndex = pairIndex;
        this.attestation = a;
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_4__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_4__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field)
], Witness.prototype, "pairIndex", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_4__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_4__.__metadata)("design:type", _exchange_lib__WEBPACK_IMPORTED_MODULE_2__.HTTPSAttestation)
], Witness.prototype, "attestation", void 0);
class Main extends _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Circuit {
    // percentGain is an integer in basis points
    static main(witness, percentChange) {
        witness.attestation.verify(_exchange_lib__WEBPACK_IMPORTED_MODULE_2__.WebSnappRequest.ofString('api.coinbase.com/trades'));
        const tradePairs = _exchange_lib__WEBPACK_IMPORTED_MODULE_2__.TradePair.readAll(witness.attestation.response);
        let pair = getElt(tradePairs, witness.pairIndex);
        let buyTotal = new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(0);
        let buyQuantities = new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(0);
        let sellTotal = new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(0);
        let sellQuantities = new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(0);
        [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade1, [buyTotal, buyQuantities, sellTotal, sellQuantities]);
        [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade2, [buyTotal, buyQuantities, sellTotal, sellQuantities]);
        [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade3, [buyTotal, buyQuantities, sellTotal, sellQuantities]);
        [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade4, [buyTotal, buyQuantities, sellTotal, sellQuantities]);
        pair.trade1.timestamp.assertLt(pair.trade2.timestamp);
        pair.trade2.timestamp.assertLt(pair.trade3.timestamp);
        pair.trade3.timestamp.assertLt(pair.trade4.timestamp);
        const FULL_BASIS = new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(10000);
        // sellTotal * (10000 + percentChange) > buyTotal * 10000;
        sellTotal.mul(FULL_BASIS.add(percentChange)).assertGte(buyTotal.mul(FULL_BASIS));
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_4__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.circuitMain,
    (0,tslib__WEBPACK_IMPORTED_MODULE_4__.__param)(1, _circuit_value__WEBPACK_IMPORTED_MODULE_1__.public_),
    (0,tslib__WEBPACK_IMPORTED_MODULE_4__.__metadata)("design:type", Function),
    (0,tslib__WEBPACK_IMPORTED_MODULE_4__.__metadata)("design:paramtypes", [Witness, _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field]),
    (0,tslib__WEBPACK_IMPORTED_MODULE_4__.__metadata)("design:returntype", void 0)
], Main, "main", null);
// takes [buyTotal, buyQuantities, sellTotal, sellQuantities] returns new ones
function accumulateTrade(trade, totals) {
    let [buyTotal, buyQuantities, sellTotal, sellQuantities] = totals;
    let spent = trade.quantity.mul(trade.price);
    [buyTotal, buyQuantities] = _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Circuit.if(trade.isBuy, [buyTotal.add(spent), buyQuantities.add(trade.quantity)], [buyTotal, buyQuantities]);
    [sellTotal, sellQuantities] = _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Circuit.if(trade.isBuy, [sellTotal, sellQuantities], [sellTotal.add(spent), sellQuantities.add(trade.quantity)]);
    return [buyTotal, buyQuantities, sellTotal, sellQuantities];
}
function getElt(xs, i) {
    let [x, found] = xs.reduce(([acc, found], x, j) => {
        let eltHere = i.equals(j);
        return [_bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Circuit.if(eltHere, x, acc), found.or(eltHere)];
    }, [xs[0], new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(false)]);
    found.assertEquals(true);
    return x;
}
function trade({ timestamp, price, quantity, isBuy }) {
    return new _exchange_lib__WEBPACK_IMPORTED_MODULE_2__.Trade(isBuy, price, quantity, timestamp);
}
function tradePair(trades) {
    return new _exchange_lib__WEBPACK_IMPORTED_MODULE_2__.TradePair(trades[0], trades[1], trades[2], trades[3]);
}
function main() {
    let before = new Date();
    const kp = Main.generateKeypair();
    let after = new Date();
    console.log('generated keypair: ', after.getTime() - before.getTime());
    const publicInput = [new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(25)];
    before = new Date();
    const proof = Main.prove([
        { pairIndex: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(1), attestation: new _exchange_lib__WEBPACK_IMPORTED_MODULE_2__.HTTPSAttestation(new _exchange_lib__WEBPACK_IMPORTED_MODULE_2__.Bytes([
                tradePair([
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) })
                ]),
                tradePair([
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(120), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(300), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(false) })
                ]),
                tradePair([
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) }),
                    trade({ timestamp: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(150), price: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(100), quantity: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(5), isBuy: new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool(true) })
                ])
            ]), new _signature__WEBPACK_IMPORTED_MODULE_3__.Signature(new _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field(1), _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar.random())) }
    ], publicInput, kp);
    after = new Date();
    console.log('generated proof: ', after.getTime() - before.getTime());
    const vk = kp.verificationKey();
    console.log(proof, kp, 'verified?', proof.verify(vk, publicInput));
}
;


/***/ }),

/***/ "./src/examples/exchange_lib.ts":
/*!**************************************!*\
  !*** ./src/examples/exchange_lib.ts ***!
  \**************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Trade": () => (/* binding */ Trade),
/* harmony export */   "TradePair": () => (/* binding */ TradePair),
/* harmony export */   "Bytes": () => (/* binding */ Bytes),
/* harmony export */   "WebSnappRequest": () => (/* binding */ WebSnappRequest),
/* harmony export */   "HTTPSAttestation": () => (/* binding */ HTTPSAttestation)
/* harmony export */ });
/* harmony import */ var tslib__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! tslib */ "./node_modules/tslib/tslib.es6.js");
/* harmony import */ var _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../bindings/snarky2 */ "./src/bindings/snarky2.js");
/* harmony import */ var _circuit_value__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../circuit_value */ "./src/circuit_value.ts");
/* harmony import */ var _signature__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../signature */ "./src/signature.ts");

// import { MerkleCollection, MerkleProof } from '../mina.js';



// type TradeObject = { timestamp: Field, price: Field, quantity: Field, isBuy: Bool };
class Trade extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    isBuy;
    price;
    quantity;
    timestamp;
    constructor(isBuy, price, quantity, timestamp) {
        super();
        this.isBuy = isBuy;
        this.price = price;
        this.quantity = quantity;
        this.timestamp = timestamp;
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool)
], Trade.prototype, "isBuy", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field)
], Trade.prototype, "price", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field)
], Trade.prototype, "quantity", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field)
], Trade.prototype, "timestamp", void 0);
// TODO: Make this an array of trades too
class TradePair extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    trade1;
    trade2;
    trade3;
    trade4;
    constructor(trade1, trade2, trade3, trade4) {
        super();
        this.trade1 = trade1;
        this.trade2 = trade2;
        this.trade3 = trade3;
        this.trade4 = trade4;
    }
    static readAll(bytes) {
        return bytes.value;
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", Trade)
], TradePair.prototype, "trade1", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", Trade)
], TradePair.prototype, "trade2", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", Trade)
], TradePair.prototype, "trade3", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", Trade)
], TradePair.prototype, "trade4", void 0);
console.log('trade size', Trade.sizeInFieldElements());
const numTradePairs = 3;
class Bytes extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    value;
    constructor(value) {
        super();
        console.assert(value.length === numTradePairs);
        this.value = value;
    }
}
Bytes.prototype._fields = [['value', _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Circuit.array(TradePair, numTradePairs)]];
class WebSnappRequest extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    constructor() {
        super();
    }
    static ofString(_) {
        return new WebSnappRequest();
    }
}
class HTTPSAttestation extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    response;
    signature;
    constructor(resp, sig) {
        super();
        this.response = resp;
        this.signature = sig;
    }
    verify(_request) {
        //const O1PUB: Group = Group.generator;
        //this.signature.verify(O1PUB, request.toFieldElements().concat(this.response.toFieldElements()))
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", Bytes)
], HTTPSAttestation.prototype, "response", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_3__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_3__.__metadata)("design:type", _signature__WEBPACK_IMPORTED_MODULE_2__.Signature)
], HTTPSAttestation.prototype, "signature", void 0);


/***/ }),

/***/ "./src/signature.ts":
/*!**************************!*\
  !*** ./src/signature.ts ***!
  \**************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "PrivateKey": () => (/* binding */ PrivateKey),
/* harmony export */   "PublicKey": () => (/* binding */ PublicKey),
/* harmony export */   "Signature": () => (/* binding */ Signature)
/* harmony export */ });
/* harmony import */ var tslib__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! tslib */ "./node_modules/tslib/tslib.es6.js");
/* harmony import */ var _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./bindings/snarky2 */ "./src/bindings/snarky2.js");
/* harmony import */ var _circuit_value__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./circuit_value */ "./src/circuit_value.ts");



class PrivateKey extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    s;
    constructor(s) {
        super();
        this.s = s;
    }
    static random() {
        return new PrivateKey(_bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar.random());
    }
    static ofBits(bs) {
        return new PrivateKey(_bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar.ofBits(bs));
    }
    toPublicKey() {
        return new PublicKey(_bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Group.generator.scale(this.s));
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_2__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_2__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar)
], PrivateKey.prototype, "s", void 0);
class PublicKey extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    g;
    constructor(g) {
        super();
        this.g = g;
    }
    static fromPrivateKey(p) {
        return p.toPublicKey();
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_2__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_2__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Group)
], PublicKey.prototype, "g", void 0);
class Signature extends _circuit_value__WEBPACK_IMPORTED_MODULE_1__.CircuitValue {
    r;
    s;
    constructor(r, s) {
        super();
        this.r = r;
        this.s = s;
    }
    static create(privKey, msg) {
        const { g: publicKey } = PublicKey.fromPrivateKey(privKey);
        const d = privKey.s;
        const kPrime = _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar.random();
        let { x: r, y: ry } = _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Group.generator.scale(kPrime);
        const k = ry.toBits()[0].toBoolean() ? kPrime.neg() : kPrime;
        const e = _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar.ofBits(_bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Poseidon.hash(msg.concat([publicKey.x, publicKey.y, r])).toBits());
        const s = e.mul(d).add(k);
        return new Signature(r, s);
    }
    verify(publicKey, msg) {
        const pubKey = publicKey.g;
        let e = _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar.ofBits(_bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Poseidon.hash(msg.concat([pubKey.x, pubKey.y, this.r])).toBits());
        let r = pubKey.scale(e).neg().add(_bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Group.generator.scale(this.s));
        return _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Bool.and(r.x.equals(this.r), r.y.toBits()[0].equals(false));
    }
}
(0,tslib__WEBPACK_IMPORTED_MODULE_2__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_2__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Field)
], Signature.prototype, "r", void 0);
(0,tslib__WEBPACK_IMPORTED_MODULE_2__.__decorate)([
    _circuit_value__WEBPACK_IMPORTED_MODULE_1__.prop,
    (0,tslib__WEBPACK_IMPORTED_MODULE_2__.__metadata)("design:type", _bindings_snarky2__WEBPACK_IMPORTED_MODULE_0__.Scalar)
], Signature.prototype, "s", void 0);
;


/***/ }),

/***/ "./node_modules/tslib/tslib.es6.js":
/*!*****************************************!*\
  !*** ./node_modules/tslib/tslib.es6.js ***!
  \*****************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "__extends": () => (/* binding */ __extends),
/* harmony export */   "__assign": () => (/* binding */ __assign),
/* harmony export */   "__rest": () => (/* binding */ __rest),
/* harmony export */   "__decorate": () => (/* binding */ __decorate),
/* harmony export */   "__param": () => (/* binding */ __param),
/* harmony export */   "__metadata": () => (/* binding */ __metadata),
/* harmony export */   "__awaiter": () => (/* binding */ __awaiter),
/* harmony export */   "__generator": () => (/* binding */ __generator),
/* harmony export */   "__createBinding": () => (/* binding */ __createBinding),
/* harmony export */   "__exportStar": () => (/* binding */ __exportStar),
/* harmony export */   "__values": () => (/* binding */ __values),
/* harmony export */   "__read": () => (/* binding */ __read),
/* harmony export */   "__spread": () => (/* binding */ __spread),
/* harmony export */   "__spreadArrays": () => (/* binding */ __spreadArrays),
/* harmony export */   "__spreadArray": () => (/* binding */ __spreadArray),
/* harmony export */   "__await": () => (/* binding */ __await),
/* harmony export */   "__asyncGenerator": () => (/* binding */ __asyncGenerator),
/* harmony export */   "__asyncDelegator": () => (/* binding */ __asyncDelegator),
/* harmony export */   "__asyncValues": () => (/* binding */ __asyncValues),
/* harmony export */   "__makeTemplateObject": () => (/* binding */ __makeTemplateObject),
/* harmony export */   "__importStar": () => (/* binding */ __importStar),
/* harmony export */   "__importDefault": () => (/* binding */ __importDefault),
/* harmony export */   "__classPrivateFieldGet": () => (/* binding */ __classPrivateFieldGet),
/* harmony export */   "__classPrivateFieldSet": () => (/* binding */ __classPrivateFieldSet)
/* harmony export */ });
/*! *****************************************************************************
Copyright (c) Microsoft Corporation.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
***************************************************************************** */
/* global Reflect, Promise */

var extendStatics = function(d, b) {
    extendStatics = Object.setPrototypeOf ||
        ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
        function (d, b) { for (var p in b) if (Object.prototype.hasOwnProperty.call(b, p)) d[p] = b[p]; };
    return extendStatics(d, b);
};

function __extends(d, b) {
    if (typeof b !== "function" && b !== null)
        throw new TypeError("Class extends value " + String(b) + " is not a constructor or null");
    extendStatics(d, b);
    function __() { this.constructor = d; }
    d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
}

var __assign = function() {
    __assign = Object.assign || function __assign(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p)) t[p] = s[p];
        }
        return t;
    }
    return __assign.apply(this, arguments);
}

function __rest(s, e) {
    var t = {};
    for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p) && e.indexOf(p) < 0)
        t[p] = s[p];
    if (s != null && typeof Object.getOwnPropertySymbols === "function")
        for (var i = 0, p = Object.getOwnPropertySymbols(s); i < p.length; i++) {
            if (e.indexOf(p[i]) < 0 && Object.prototype.propertyIsEnumerable.call(s, p[i]))
                t[p[i]] = s[p[i]];
        }
    return t;
}

function __decorate(decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
}

function __param(paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
}

function __metadata(metadataKey, metadataValue) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(metadataKey, metadataValue);
}

function __awaiter(thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
}

function __generator(thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (_) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
}

var __createBinding = Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
});

function __exportStar(m, o) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(o, p)) __createBinding(o, m, p);
}

function __values(o) {
    var s = typeof Symbol === "function" && Symbol.iterator, m = s && o[s], i = 0;
    if (m) return m.call(o);
    if (o && typeof o.length === "number") return {
        next: function () {
            if (o && i >= o.length) o = void 0;
            return { value: o && o[i++], done: !o };
        }
    };
    throw new TypeError(s ? "Object is not iterable." : "Symbol.iterator is not defined.");
}

function __read(o, n) {
    var m = typeof Symbol === "function" && o[Symbol.iterator];
    if (!m) return o;
    var i = m.call(o), r, ar = [], e;
    try {
        while ((n === void 0 || n-- > 0) && !(r = i.next()).done) ar.push(r.value);
    }
    catch (error) { e = { error: error }; }
    finally {
        try {
            if (r && !r.done && (m = i["return"])) m.call(i);
        }
        finally { if (e) throw e.error; }
    }
    return ar;
}

/** @deprecated */
function __spread() {
    for (var ar = [], i = 0; i < arguments.length; i++)
        ar = ar.concat(__read(arguments[i]));
    return ar;
}

/** @deprecated */
function __spreadArrays() {
    for (var s = 0, i = 0, il = arguments.length; i < il; i++) s += arguments[i].length;
    for (var r = Array(s), k = 0, i = 0; i < il; i++)
        for (var a = arguments[i], j = 0, jl = a.length; j < jl; j++, k++)
            r[k] = a[j];
    return r;
}

function __spreadArray(to, from, pack) {
    if (pack || arguments.length === 2) for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
            if (!ar) ar = Array.prototype.slice.call(from, 0, i);
            ar[i] = from[i];
        }
    }
    return to.concat(ar || from);
}

function __await(v) {
    return this instanceof __await ? (this.v = v, this) : new __await(v);
}

function __asyncGenerator(thisArg, _arguments, generator) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var g = generator.apply(thisArg, _arguments || []), i, q = [];
    return i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i;
    function verb(n) { if (g[n]) i[n] = function (v) { return new Promise(function (a, b) { q.push([n, v, a, b]) > 1 || resume(n, v); }); }; }
    function resume(n, v) { try { step(g[n](v)); } catch (e) { settle(q[0][3], e); } }
    function step(r) { r.value instanceof __await ? Promise.resolve(r.value.v).then(fulfill, reject) : settle(q[0][2], r); }
    function fulfill(value) { resume("next", value); }
    function reject(value) { resume("throw", value); }
    function settle(f, v) { if (f(v), q.shift(), q.length) resume(q[0][0], q[0][1]); }
}

function __asyncDelegator(o) {
    var i, p;
    return i = {}, verb("next"), verb("throw", function (e) { throw e; }), verb("return"), i[Symbol.iterator] = function () { return this; }, i;
    function verb(n, f) { i[n] = o[n] ? function (v) { return (p = !p) ? { value: __await(o[n](v)), done: n === "return" } : f ? f(v) : v; } : f; }
}

function __asyncValues(o) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var m = o[Symbol.asyncIterator], i;
    return m ? m.call(o) : (o = typeof __values === "function" ? __values(o) : o[Symbol.iterator](), i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i);
    function verb(n) { i[n] = o[n] && function (v) { return new Promise(function (resolve, reject) { v = o[n](v), settle(resolve, reject, v.done, v.value); }); }; }
    function settle(resolve, reject, d, v) { Promise.resolve(v).then(function(v) { resolve({ value: v, done: d }); }, reject); }
}

function __makeTemplateObject(cooked, raw) {
    if (Object.defineProperty) { Object.defineProperty(cooked, "raw", { value: raw }); } else { cooked.raw = raw; }
    return cooked;
};

var __setModuleDefault = Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
};

function __importStar(mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
}

function __importDefault(mod) {
    return (mod && mod.__esModule) ? mod : { default: mod };
}

function __classPrivateFieldGet(receiver, state, kind, f) {
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a getter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot read private member from an object whose class did not declare it");
    return kind === "m" ? f : kind === "a" ? f.call(receiver) : f ? f.value : state.get(receiver);
}

function __classPrivateFieldSet(receiver, state, value, kind, f) {
    if (kind === "m") throw new TypeError("Private method is not writable");
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a setter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot write private member to an object whose class did not declare it");
    return (kind === "a" ? f.call(receiver, value) : f ? f.value = value : state.set(receiver, value)), value;
}


/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/compat get default export */
/******/ 	(() => {
/******/ 		// getDefaultExport function for compatibility with non-harmony modules
/******/ 		__webpack_require__.n = (module) => {
/******/ 			var getter = module && module.__esModule ?
/******/ 				() => (module['default']) :
/******/ 				() => (module);
/******/ 			__webpack_require__.d(getter, { a: getter });
/******/ 			return getter;
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry need to be wrapped in an IIFE because it need to be in strict mode.
(() => {
"use strict";
/*!**********************!*\
  !*** ./src/index.ts ***!
  \**********************/
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "exchange": () => (/* binding */ exchange),
/* harmony export */   "five": () => (/* binding */ five)
/* harmony export */ });
/* harmony import */ var _examples_exchange__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./examples/exchange */ "./src/examples/exchange.ts");

const exchange = _examples_exchange__WEBPACK_IMPORTED_MODULE_0__.main;
exchange();
// for testing tests
const five = 5;

})();

/******/ })()
;