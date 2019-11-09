﻿using System;
using System.Runtime.Serialization;
using System.Security.Permissions;

namespace PSRule.Rules.Azure.Pipeline
{
    /// <summary>
    /// A base class for all pipeline exceptions.
    /// </summary>
    public abstract class PipelineException : Exception
    {
        /// <summary>
        /// Creates a pipeline exception.
        /// </summary>
        protected PipelineException()
        {
        }

        /// <summary>
        /// Creates a pipeline exception.
        /// </summary>
        /// <param name="message">The detail of the exception.</param>
        protected PipelineException(string message) : base(message)
        {
        }

        /// <summary>
        /// Creates a pipeline exception.
        /// </summary>
        /// <param name="message">The detail of the exception.</param>
        /// <param name="innerException">A nested exception that caused the issue.</param>
        protected PipelineException(string message, Exception innerException) : base(message, innerException)
        {
        }

        protected PipelineException(SerializationInfo info, StreamingContext context)
            : base(info, context)
        {
        }
    }

    /// <summary>
    /// A serialization exception.
    /// </summary>
    [Serializable]
    public sealed class PipelineSerializationException : PipelineException
    {
        /// <summary>
        /// Creates a serialization exception.
        /// </summary>
        public PipelineSerializationException()
        {
        }

        /// <summary>
        /// Creates a serialization exception.
        /// </summary>
        /// <param name="message">The detail of the exception.</param>
        public PipelineSerializationException(string message) : base(message)
        {
        }

        /// <summary>
        /// Creates a serialization exception.
        /// </summary>
        /// <param name="message">The detail of the exception.</param>
        /// <param name="innerException">A nested exception that caused the issue.</param>
        public PipelineSerializationException(string message, Exception innerException) : base(message, innerException)
        {
        }

        private PipelineSerializationException(SerializationInfo info, StreamingContext context) : base(info, context)
        {
        }

        [SecurityPermission(SecurityAction.Demand, SerializationFormatter = true)]
        public override void GetObjectData(SerializationInfo info, StreamingContext context)
        {
            if (info == null) throw new ArgumentNullException("info");
            base.GetObjectData(info, context);
        }
    }
}
