// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

package com.microsoft.bond;

/**
 * Denotes a Bond struct type.
 * All generated Bond struct classes implement this interface.
 */
public interface BondSerializable {

    /**
     * Returns the {@link BondType} type descriptor for the current struct type.
     *
     * @return the type descriptor
     */
    StructBondType<? extends BondSerializable> getBondType();
}
